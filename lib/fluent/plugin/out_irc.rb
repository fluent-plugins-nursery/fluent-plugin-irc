module Fluent
  class IRCOutput < Fluent::Output
    Fluent::Plugin.register_output('irc', self)

    include SetTimeKeyMixin
    include SetTagKeyMixin

    config_set_default :include_time_key, true
    config_set_default :include_tag_key, true

    config_param :host        , :string  , :default => 'localhost'
    config_param :port        , :integer , :default => 6667
    config_param :channel     , :string
    config_param :nick        , :string  , :default => 'fluentd'
    config_param :user        , :string  , :default => 'fluentd'
    config_param :real        , :string  , :default => 'fluentd'
    config_param :message     , :string
    config_param :out_keys do |val|
      val.split(',')
    end
    config_param :time_key    , :string  , :default => nil
    config_param :time_format , :string  , :default => nil
    config_param :tag_key     , :string  , :default => 'tag'


    def initialize
      super
      require 'irc_parser'
    end

    def configure(conf)
      super
      begin
        @message % (['1'] * @out_keys.length)
      rescue ArgumentError
        raise Fluent::ConfigError, "string specifier '%s' and out_keys specification mismatch"
      end
    end

    def start
      super
      begin
        @client = IRCConnection.connect(@host, @port)
      rescue
        raise Fluent::ConfigError, "failto connect IRC server #{@host}:#{@port}"
      end

      @client.channel = '#'+@channel
      @client.nick = @nick
      @client.user = @user
      @client.real = @real
      @client.attach(Coolio::Loop.default)
    end

    def shutdown
      super
      @client.close
    end

    def emit(tag, es, chain)
      chain.next
      es.each do |time,record|
        filter_record(tag, time, record)
        IRCParser.message(:priv_msg) do |m|
          m.target = @client.channel
          m.body = build_message(record)
          @client.send m
        end
      end
    end

    private
    def build_message(record)
      values = @out_keys.map {|key| record[key].to_s}
      @message % values
    end

    class IRCConnection < Cool.io::TCPSocket
      attr_accessor :channel, :nick, :user, :real

      def on_connect
        IRCParser.message(:nick) do |m|
          m.nick   = @nick
          write m
        end
        IRCParser.message(:user) do |m|
          m.user = @user
          m.postfix = @real
          write m
        end
      end

      def on_close
        #TODO
      end

      def on_read(data)
        data.each_line do |line|
          begin
            msg = IRCParser.parse(line)
            case msg.class.to_sym
            when :rpl_welcome
              IRCParser.message(:join) do |m|
                m.channels = @channel
                write m
              end
            when :ping
              IRCParser.message(:pong) do |m|
                m.target = msg.target
                m.body = msg.body
                write m
              end
            end
          rescue
            #TODO
          end
        end
      end

      def on_resolve_failed
        #TODO
      end

      def on_connect_failed
        #TODO
      end

      def send(msg)
        write msg
      end
    end
  end
end
