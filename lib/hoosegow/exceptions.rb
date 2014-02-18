class Hoosegow
  # General error for others to inherit from.
  class Error < StandardError; end

  # Errors while building the Docker image.
  class ImageBuildError < Error
    def initialize(message)
      if message.is_a?(Hash)
        @detail = message['errorDetail']
        message = message['error']
      end
      super(message)
    end

    # The error details from docker.
    #
    # Example:
    #     {"code" => 127, "message" => "The command [/bin/sh -c boom] returned a non-zero code: 127"}
    attr_reader :detail
  end

  # Errors while importing dependencies
  class InmateImportError < Error; end
end
