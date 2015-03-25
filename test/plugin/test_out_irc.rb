require 'helper'
require 'socket'

class IRCOutputTest < Test::Unit::TestCase
  TAG = "test"
  PORT = 6667
  CHANNEL = "fluentd"
  NICK = "fluentd"
  USER = "fluentd"
  REAL = "fluentd"
  COMMAND = :notice
  MESSAGE = "notice: %s [%s] %s"
  TIME_FORMAT = "%Y/%m/%d %H:%M:%S"

  def setup
    Fluent::Test.setup
    Fluent::Engine.now = Time.now
  end

  def config(
    port: PORT,
    channel: CHANNEL,
    channel_keys: "",
    command: COMMAND.to_s,
    command_keys: nil
  )
    config = %[
      type irc
      host localhost
      port #{port}
      channel #{channel}
      channel_keys #{channel_keys}
      nick #{NICK}
      user #{USER}
      real #{REAL}
      command #{command}
      message #{MESSAGE}
      out_keys tag,time,msg
      time_key time
      time_format #{TIME_FORMAT}
      tag_key tag
      send_queue_limit 10
      send_interval 0.5
    ]
    config += %[command_keys #{command_keys}] if command_keys
    config
  end


  def create_driver(conf = config)
    Fluent::Test::OutputTestDriver.new(Fluent::IRCOutput, TAG).configure(conf)
  end

  def test_configure
    d = create_driver

    assert_equal "localhost", d.instance.host
    assert_equal PORT, d.instance.port
    assert_equal "##{CHANNEL}", d.instance.channel
    assert_equal NICK, d.instance.nick
    assert_equal USER, d.instance.user
    assert_equal REAL, d.instance.real
    assert_equal COMMAND, d.instance.command
    assert_equal MESSAGE, d.instance.message
    assert_equal ["tag","time","msg"], d.instance.out_keys
    assert_equal "time", d.instance.time_key
    assert_equal TIME_FORMAT, d.instance.time_format
    assert_equal "tag", d.instance.tag_key
    assert_equal 10,  d.instance.send_queue_limit
    assert_equal 0.5, d.instance.send_interval
  end

  def test_configure_channel_keys
    d = create_driver(config(channel:"%s", channel_keys:"channel"))
    assert_equal "#%s", d.instance.channel
    assert_equal ["channel"], d.instance.channel_keys
  end

  def test_configure_command_keys
    d = create_driver(config(command:"%s", command_keys:"command"))
    assert_equal "%s", d.instance.command
    assert_equal ["command"], d.instance.command_keys
  end

  def test_configure_command
    assert_raise Fluent::ConfigError do
      create_driver(config(command: 'foo'))
    end

    assert_nothing_raised { create_driver(config(command: 'priv_msg')) }
    assert_nothing_raised { create_driver(config(command: 'privmsg')) }
    assert_nothing_raised { create_driver(config(command: 'notice')) }
  end

  def test_emit
    msg = "test"
    msgs = [{"msg" => msg}]
    body = MESSAGE % [TAG, Time.at(Fluent::Engine.now).utc.strftime(TIME_FORMAT), msg]

    emit_test(msgs) do |socket|
      m = IRCParser.parse(socket.gets)
      assert_equal :nick, m.class.to_sym
      assert_equal NICK, m.nick

      m = IRCParser.parse(socket.gets)
      assert_equal :user, m.class.to_sym
      assert_equal USER, m.user
      assert_equal REAL, m.postfix

      m = IRCParser.parse(socket.gets)
      assert_equal :join, m.class.to_sym, :join
      assert_equal ["##{CHANNEL}"], m.channels

      m = IRCParser.parse(socket.gets)
      assert_equal COMMAND, m.class.to_sym
      assert_equal "##{CHANNEL}", m.target
      assert_equal body, m.body

      assert_nil socket.gets # expects EOF
    end
  end

  def test_dynamic_channel
    msgs = [
      {"msg" => "test", "channel" => "chan1"},
      {"msg" => "test", "channel" => "chan2"},
      {"msg" => "test", "channel" => "chan1"},
    ]

    extra_config = {
      channel: "%s",
      channel_keys: "channel",
    }

    emit_test(msgs, extra_config: extra_config) do |socket|
      socket.gets # ignore NICK
      socket.gets # ignore USER

      m = IRCParser.parse(socket.gets)
      assert_equal :join, m.class.to_sym
      assert_equal ["#chan1"], m.channels

      m = IRCParser.parse(socket.gets)
      assert_equal COMMAND, m.class.to_sym
      assert_equal "#chan1", m.target

      m = IRCParser.parse(socket.gets)
      assert_equal :join, m.class.to_sym
      assert_equal ["#chan2"], m.channels

      m = IRCParser.parse(socket.gets)
      assert_equal COMMAND, m.class.to_sym
      assert_equal "#chan2", m.target

      m = IRCParser.parse(socket.gets)
      assert_equal COMMAND, m.class.to_sym
      assert_equal "#chan1", m.target

      assert_nil socket.gets # expects EOF
    end
  end

  def test_dynamic_command
    msgs = [
      {"msg" => "test", "command" => "privmsg"},
      {"msg" => "test", "command" => "priv_msg"},
      {"msg" => "test", "command" => "notice"},
      {"msg" => "test", "command" => "something_wrong"},
    ]

    extra_config = {
      command: "%s",
      command_keys: "command",
    }

    emit_test(msgs, extra_config: extra_config) do |socket|
      socket.gets # ignore NICK
      socket.gets # ignore USER

      m = IRCParser.parse(socket.gets)
      assert_equal :join, m.class.to_sym

      m = IRCParser.parse(socket.gets)
      assert_equal :priv_msg, m.class.to_sym

      m = IRCParser.parse(socket.gets)
      assert_equal :priv_msg, m.class.to_sym

      m = IRCParser.parse(socket.gets)
      assert_equal :notice, m.class.to_sym

      m = IRCParser.parse(socket.gets)
      assert_equal :priv_msg, m.class.to_sym # replaced by default priv_msg

      assert_nil socket.gets # expects EOF
    end
  end

  def test_fallback_err_nick_name_in_use
    msgs = [
      {"msg" => "test", "command" => "privmsg"},
    ]

    emit_test(msgs) do |socket, d|
      socket.gets # ignore NICK
      socket.gets # ignore USER
      socket.gets # ignore join
      socket.gets # ignore priv_msg

      # imitate to receive :err_nick_name_in_use
      conn = d.instance.instance_variable_get(:@conn)
      IRCParser.message(:err_nick_name_in_use) do |m|
        conn.on_read(m.to_s)
      end

      sleep 1

      # test to use `#{NICK}_` instead
      m = IRCParser.parse(socket.gets)
      assert_equal :nick, m.class.to_sym
      assert_equal "#{NICK}_", m.nick
    end
  end

  private

  def emit_test(msgs, extra_config: {}, &block)
    TCPServer.open(0) do |serv|
      port = serv.addr[1]
      d = create_driver(config({port: port}.merge(extra_config)))

      thread = Thread.new do
        s = serv.accept
        block.call(s, d)
        s.close
      end

      d.run do
        msgs.each do |m|
          d.emit(m, Fluent::Engine.now)
          channel = d.instance.on_timer
          d.instance.conn.joined[channel] = true # pseudo join
        end
        # How to remove sleep?
        # It is necessary to ensure that no data remains in Cool.io write buffer before detach.
        sleep 1
      end

      thread.join
    end
  end
end
