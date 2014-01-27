class Hoosegow
  # General error for others to inherit from.
  class Error < StandardError; end

  # Errors while building the Docker image.
  class ImageBuildError < Error; end

  # Errors while importing dependencies
  class InmateImportError < Error; end
end
