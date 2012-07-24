require 'helper'

class IRCOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    host localhost
    port 6667
    #channel #fluentd
    nick fluentd
    user fluentd
    real fluentd
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::OutputTestDriver.new(Fluent::IRCOutput).configure(conf)
  end

  def test_configure
    d = create_driver

    assert_equal "localhost", d.instance.host
    assert_equal 6667, d.instance.port
    assert_equal "fluentd", d.instance.nick
    assert_equal "fluentd", d.instance.user
    assert_equal "fluentd", d.instance.real
    p d.instance
  end

  #def test_emit
    #TODO
  #end
end
