class Hoosegow
  # General error for others to inherit from.
  class Error < StandardError; end

  # Errors while building the Docker image.
  class ImageBuildError < Error
    def initialize(message_or_docker_build_hash)
      if message_or_docker_build_hash.is_a?(Hash)
        @status = message_or_docker_build_hash
        message = @status['message']
      else
        message = message_or_docker_build_hash
      end
      super(message)
    end

    # The full error message from docker.
    attr_reader :status
  end

  # Errors while importing dependencies
  class InmateImportError < Error; end
end
