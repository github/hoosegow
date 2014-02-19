class Hoosegow
  module Protocol
    # Sends data to and from an inmate, via a Docker container running `bin/hoosegow`.
    class Proxy
      def initialize(options)
        @yield_block = options.fetch(:yield)
        @stdout      = options.fetch(:stdout)
        @stderr      = options.fetch(:stderr)
      end

      # Encodes a "send" method call for an inmate.
      def encode_send(method_name, args)
        MessagePack.pack([method_name, args])
      end

      # The return value
      attr_reader :return_value

      # Decodes a message from an inmate via docker.
      def receive(data)
        data = (@buffer || '') + data
        while data.size >= 8
          header = data.slice!(0,8)
          docker_type, length = header.unpack('CxxxN')
          if data.bytesize < length
            data = header + data
            break
          end
          docker_message = data.slice!(0, length)
          if docker_type == 1
            @unpacker ||= MessagePack::Unpacker.new
            @unpacker.feed_each(docker_message) do |decoded|
              inmate_type, inmate_value = decoded
              case inmate_type.to_s
              when 'yield'
                @yield_block.call(*inmate_value) if @yield_block
              when 'return'
                @return_value = inmate_value
              when 'raise'
                raise Hoosegow::InmateRuntimeError, "#{inmate_value['class']}: #{inmate_value['message']}"
              when 'stdout'
                @stdout.write(inmate_value)
              end
            end
          elsif docker_type == 2
            @stderr.write(docker_message)
          end
        end
        @buffer = data
      end
    end

    # Translates output (STDOUT, yields, and return value) from an inner invocation
    # of `bin/hoosegow` into a single `STDOUT` stream.
    class EntryPoint
      def initialize(options)
        @stdout        = options.fetch(:stdout)
        @inmate_stdout = options.fetch(:inmate_stdout)
        @sidechannel   = options.fetch(:sidechannel)
      end

      def start!
        @thread = Thread.new { run_loop }
        self
      end

      def finish!
        @stop = true
        @thread.join
      end

      private

      def run_loop
        ios = [@inmate_stdout, @sidechannel]
        loop do
          readers, _, _ = IO.select(ios, nil, nil, 1)
          if readers.nil?
            break if @stop
          else
            readers.each do |r|
              begin
                if r == @sidechannel
                  read_sidechannel
                else
                  read_stdout
                end
              rescue EOFError
                # stream was closed.
                ios.delete(r)
              end
            end
          end
          break if ios.empty?
        end
      end

      def read_sidechannel
        @unpacker ||= MessagePack::Unpacker.new
        @unpacker.feed_each(@sidechannel.read_nonblock(100000)) do |obj|
          @stdout.write(MessagePack.pack(obj))
        end
      end

      def read_stdout
        @stdout.write(MessagePack.pack([:stdout, @inmate_stdout.read_nonblock(100000)]))
      end
    end

    # Translates stdin into a method call on on inmate.
    # Encodes yields and the return value onto a stream.
    class Inmate
      def initialize(options)
        @inmate      = options.fetch(:inmate)
        @stdin       = options.fetch(:stdin)
        @sidechannel = options.fetch(:sidechannel)
      end

      def run!
        name, args = MessagePack.unpack(@stdin.read)
        result = @inmate.send(name, *args) do |*yielded|
          report(:yield, yielded)
        end
        report(:return, result)
      rescue => e
        report(:raise, {:class => e.class.name, :message => e.message})
      end

      private

      def report(type, data)
        @sidechannel.write(MessagePack.pack([type, data]))
      end
    end
  end
end
