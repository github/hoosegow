require 'msgpack'
require 'thread'

class Hoosegow
  # See docs/dispatch.md for more information.
  module Protocol
    # Hoosegow, on the app side of the proxy.
    #
    # Sends data to and from an inmate, via a Docker container running `bin/hoosegow`.
    class Proxy
      # Options:
      # * (optional) :yield - a block to call when the inmate yields
      # * (optional) :stdout - an IO for writing STDOUT from the inmate
      # * (optional) :stderr - an IO for writing STDERR from the inmate
      def initialize(options)
        @yield_block = options.fetch(:yield, nil)
        @stdout      = options.fetch(:stdout, $stdout)
        @stderr      = options.fetch(:stderr, $stderr)
      end

      # Encodes a "send" method call for an inmate.
      def encode_send(method_name, args)
        MessagePack.pack([method_name, args])
      end

      # The return value
      attr_reader :return_value

      # Decodes a message from an inmate via docker.
      def receive(type, msg)
        if type == :stdout
          @unpacker ||= MessagePack::Unpacker.new
          @unpacker.feed_each(msg) do |decoded|
            inmate_type, inmate_value = decoded
            case inmate_type.to_s
            when 'yield'
              @yield_block.call(*inmate_value) if @yield_block
            when 'return'
              @return_value = inmate_value
            when 'raise'
              raise(*raise_args(inmate_value))
            when 'stdout'
              @stdout.write(inmate_value)
            end
          end
        elsif type == :stderr
          @stderr.write(msg)
        end
      end

      def raise_args(remote_error)
        exception_class = Hoosegow::InmateRuntimeError
        exception_message = "#{remote_error['class']}: #{remote_error['message']}"
        if remote_backtrace = remote_error['backtrace']
          exception_message << ("\n" + Array(remote_backtrace).join("\n"))
        end
        [exception_class, exception_message]
      end
    end

    # bin/hoosegow client (where the inmate code runs)
    #
    # Translates stdin into a method call on on inmate.
    # Encodes yields and the return value onto a stream.
    class Inmate
      def self.run(options)
        o = new(options)
        o.intercepting do
          o.run
        end
      end

      # Options:
      # * :stdout - real stdout, where we can write things that our parent process will see
      # * :intercepted - where this process or child processes write STDOUT to
      # * (optional) :inmate - the hoosegow instance to use as the inmate.
      # * (optional) :stdin - where to read the encoded method call data.
      def initialize(options)
        @inmate       = options.fetch(:inmate) { Hoosegow.new(:no_proxy => true) }
        @stdin        = options.fetch(:stdin, $stdin)
        @stdout       = options.fetch(:stdout)
        @intercepted  = options.fetch(:intercepted)
        @stdout_mutex = Mutex.new
      end

      def run
        name, args = MessagePack::Unpacker.new(@stdin).read
        result = @inmate.send(name, *args) do |*yielded|
          report(:yield, yielded)
          nil # Don't return anything from the inmate's `yield`.
        end
        report(:return, result)
      rescue Exception => e
        report(:raise, {:class => e.class.name, :message => e.message, :backtrace => e.backtrace})
      end

      def intercepting
        start_intercepting
        yield
      ensure
        stop_intercepting
      end

      def start_intercepting
        @intercepting = true
        @intercept_thread = Thread.new do
          begin
            loop do
              if IO.select([@intercepted], nil, nil, 0.1)
                report(:stdout, @intercepted.read_nonblock(100000))
              elsif ! @intercepting
                break
              end
            end
          rescue EOFError
            # stdout is closed, so we can stop checking it.
          end
        end
      end

      def stop_intercepting
        @intercepting = false
        @intercept_thread.join
      end

      private

      def report(type, data)
        @stdout_mutex.synchronize { @stdout.write(MessagePack.pack([type, data])) }
      end
    end
  end
end
