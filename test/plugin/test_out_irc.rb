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
    command_key: nil
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
      command #{COMMAND.to_s}
      message #{MESSAGE}
      out_keys tag,time,msg
      time_key time
      time_format #{TIME_FORMAT}
      tag_key tag
    ]
    config += %[command_key #{command_key}] if command_key
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
  end

  def test_configure_channel_keys
    d = create_driver(config(channel:"%s", channel_keys:"channel"))
    assert_equal "#%s", d.instance.channel
    assert_equal ["channel"], d.instance.channel_keys
  end

  def test_emit
    msg = "test"
    msgs = [{"msg" => msg}]
    body = MESSAGE % [TAG, Time.at(Fluent::Engine.now).utc.strftime(TIME_FORMAT), msg]

    emit_test(msgs) do |socket|
      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :nick
      assert_equal m.nick, NICK

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :user
      assert_equal m.user, USER
      assert_equal m.postfix, REAL

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :join
      assert_equal m.channels, ["##{CHANNEL}"]

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, COMMAND
      assert_equal m.target, "##{CHANNEL}"
      assert_equal m.body, body

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
      assert_equal m.class.to_sym, :join
      assert_equal m.channels, ["#chan1"]

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, COMMAND
      assert_equal m.target, "#chan1"

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :join
      assert_equal m.channels, ["#chan2"]

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, COMMAND
      assert_equal m.target, "#chan2"

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, COMMAND
      assert_equal m.target, "#chan1"

      assert_nil socket.gets # expects EOF
    end
  end

  def test_dynamic_command
    msgs = [
      {"msg" => "test", "command" => "privmsg"},
      {"msg" => "test", "command" => "priv_msg"},
      {"msg" => "test", "command" => "notice"},
    ]

    extra_config = {
      command_key: "command",
    }

    emit_test(msgs, extra_config: extra_config) do |socket|
      socket.gets # ignore NICK
      socket.gets # ignore USER

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :join

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :priv_msg

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :priv_msg

      m = IRCParser.parse(socket.gets)
      assert_equal m.class.to_sym, :notice

      assert_nil socket.gets # expects EOF
    end
  end

  private

  def emit_test(msgs, extra_config: {}, &block)
    TCPServer.open(0) do |serv|
      port = serv.addr[1]
      d = create_driver(config({port: port}.merge(extra_config)))

      thread = Thread.new do
        s = serv.accept
        block.call(s)
        s.close
      end

      d.run do
        msgs.each do |m|
          d.emit(m, Fluent::Engine.now)
        end
        # How to remove sleep?
        # It is necessary to ensure that no data remains in Cool.io write buffer before detach.
        sleep 1
      end

      thread.join
    end
  end
end
