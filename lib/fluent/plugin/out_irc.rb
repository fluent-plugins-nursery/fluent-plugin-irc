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
    config_param :channel_keys, :default => nil do |val|
      val.split(',')
    end
    config_param :nick        , :string  , :default => 'fluentd'
    config_param :user        , :string  , :default => 'fluentd'
    config_param :real        , :string  , :default => 'fluentd'
    config_param :password    , :string  , :default => nil
    config_param :message     , :string
    config_param :out_keys do |val|
      val.split(',')
    end
    config_param :time_key    , :string  , :default => 'time'
    config_param :time_format , :string  , :default => '%Y/%m/%d %H:%M:%S'
    config_param :tag_key     , :string  , :default => 'tag'
    config_param :command     , :string  , :default => 'priv_msg'

    COMMAND_LIST = %w[priv_msg notice]

    # To support log_level option implemented by Fluentd v0.10.43
    unless method_defined?(:log)
      define_method("log") { $log }
    end

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

      if @channel_keys
        begin
          @channel % (['1'] * @channel_keys.length)
        rescue ArgumentError
          raise Fluent::ConfigError, "string specifier '%s' and channel_keys specification mismatch"
        end
      end
      @channel = '#'+@channel

      unless COMMAND_LIST.include?(@command)
        raise Fluent::ConfigError, "command must be one of #{COMMAND_LIST.join(', ')}"
      end

    end

    def start
      super

      begin
        @loop = Coolio::Loop.default
        @conn = create_connection
      rescue
        raise Fluent::ConfigError, "failed to connect IRC server #{@host}:#{@port}"
      end
    end

    def shutdown
      super
      @conn.close unless @conn.closed?
    end

    def emit(tag, es, chain)
      chain.next

      if @conn.closed?
        log.warn "out_irc: connection is closed. try to reconnect"
        @conn = create_connection
      end

      es.each do |time,record|
        filter_record(tag, time, record)
        @conn.send_message(build_message(record), build_channel(record))
      end
    end

    private

    def create_connection
      conn = IRCConnection.connect(@host, @port)
      conn.command = @command
      conn.channel = '#'+@channel
      conn.nick = @nick
      conn.user = @user
      conn.real = @real
      conn.password = @password
      conn.attach(@loop)
      conn
    end

    def build_message(record)
      values = @out_keys.map do |key|
        begin
          record.fetch(key).to_s
        rescue KeyError
          log.warn "out_irc: the specified key '#{key}' not found in record. [#{record}]"
          ''
        end
      end

      @message % values
    end

    def build_channel(record)
      return @channel unless @channel_keys

      values = @channel_keys.map do |key|
        begin
          record.fetch(key).to_s
        rescue KeyError
          $log.warn "out_irc: the specified key '#{key}' not found in record. [#{record}]"
          ''
        end
      end

      @channel % values
    end

    class IRCConnection < Cool.io::TCPSocket
      attr_accessor :command, :channel, :nick, :user, :real, :password

      def initialize(*args)
        super
        @joined = {}
      end

      def on_connect
        if @password
          IRCParser.message(:pass) do |m|
            m.password = @password
            write m
          end
        end
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

      def on_read(data)
        data.each_line do |line|
          begin
            msg = IRCParser.parse(line)
            case msg.class.to_sym
            when :ping
              IRCParser.message(:pong) do |m|
                m.target = msg.target
                m.body = msg.body
                write m
              end
            when :error
              log.warn "out_irc: an error occured. \"#{msg.error_message}\""
            end
          rescue
            #TODO
          end
        end
      end

      def joined?(channel)
        @joined[channel]
      end

      def join(channel)
        IRCParser.message(:join) do |m|
          m.channels = channel
          write m
        end
        @joined[channel] = true
      end

      def send_message(msg, channel)
        join(channel) unless joined?(channel)
        IRCParser.message(@command) do |m|
          m.target = channel
          m.body = msg
          write m
        end
      end
    end
  end
end
