class Hoosegow
  module Protocol
    # Sends data to and from an inmate, via a Docker container running `bin/hoosegow`.
    class Proxy
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
        loop do
          readers, _, _ = IO.select([@inmate_stdout, @sidechannel], nil, nil, 1)
          if readers.nil?
            break if @stop
          else
            readers.each do |r|
              if r == @sidechannel
                read_sidechannel
              else
                read_stdout
              end
            end
          end
            break if @stop
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
