require 'helper'

class IRCOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    type irc
    host localhost
    port 6667
    channel fluentd
    nick fluentd
    user fluentd
    real fluentd
    message notice: %s [%s] %s
    out_keys tag,time,msg
    time_key time
    time_format %Y/%m/%d %H:%M:%S
    tag_key tag
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::OutputTestDriver.new(Fluent::IRCOutput).configure(conf)
  end

  def test_configure
    d = create_driver

    assert_equal "localhost", d.instance.host
    assert_equal 6667, d.instance.port
    assert_equal "fluentd", d.instance.channel
    assert_equal "fluentd", d.instance.nick
    assert_equal "fluentd", d.instance.user
    assert_equal "fluentd", d.instance.real
    assert_equal "notice: %s [%s] %s", d.instance.message
    assert_equal ["tag","time","msg"], d.instance.out_keys
    assert_equal "time", d.instance.time_key
    assert_equal "%Y/%m/%d %H:%M:%S", d.instance.time_format
    assert_equal "tag", d.instance.tag_key
  end

  #def test_emit
    #TODO
  #end
end
