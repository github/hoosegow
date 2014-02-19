class Hoosegow
  module Protocol
    # Sends data to and from an inmate, via a Docker container running `bin/hoosegow`.
    class Proxy
    end

    # Translates output (STDOUT, yields, and return value) from an inner invocation
    # of `bin/hoosegow` into a single `STDOUT` stream.
    class EntryPoint
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
        report(:raise, result)
      end

      private

      def report(type, data)
        @sidechannel.write(MessagePack.pack([type, data]))
      end
    end
  end
end
