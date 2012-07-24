module Fluent
  class IRCOutput < Fluent::Output
    Fluent::Plugin.register_output('irc', self)

    config_param :host    , :string  , :default => 'localhost'
    config_param :port    , :integer , :default => 6667
    config_param :channel , :string  , :default => 'fluentd'
    config_param :nick    , :string  , :default => 'fluentd'
    config_param :user    , :string  , :default => 'fluentd'
    config_param :real    , :string  , :default => 'fluentd'

    def initialize
      super
      require 'irc_parser'
    end

    def start
      super
      @client = IRCConnection.connect(@host, @port)
      @client.channel = '#'+@channel
      @client.nick = @nick
      @client.user = @user
      @client.real = @real
      @client.attach(Coolio::Loop.default)
    end

    def shutdown
      super
    end

    def emit(tag, es, chain)
      chain.next
      es.each do |time,record|
        IRCParser.message(:priv_msg) do |m|
          m.target = @client.channel
          m.body = record.to_json
          @client.send m
        end
      end
    end

    private
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
