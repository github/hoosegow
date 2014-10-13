require 'fileutils'

class Hoosegow
  class ImageBundle
    # Public: The source for the Dockerfile. Defaults to Dockerfile in the hoosegow gem.
    attr_accessor :dockerfile

    # Public: The ruby version to install on the container.
    attr_accessor :ruby_version

    # Public: Include files in the bundle.
    #
    # To add all files in "root" to the root of the bundle:
    #     add("root/*")
    #
    # To add all files other than files that start with "." to the root of the bundle:
    #     add("root/*", :ignore_hidden => true)
    #
    # To add all files in "lib" to "vendor/lib":
    #     add("lib/*", :prefix => "vendor/lib")
    #     add("lib", :prefix => "vendor")
    def add(glob, options)
      definition << options.merge(:glob => glob)
    end

    # Public: Exclude files from the bundle.
    #
    # To exclude "Gemfile.lock":
    #     exclude("Gemfile.lock")
    def exclude(path)
      excludes << path
    end

    # Public: The default name of the docker image, based on the tarball's hash.
    def image_name
      (tarball && @image_name)
    end

    # Tarball of this gem and the inmate file. Used for building an image.
    #
    # Returns the tar file's bytes.
    def tarball
      return @tarball if defined? @tarball

      require 'open3'
      Dir.mktmpdir do |tmpdir|
        definition.each do |options|
          glob          = options.fetch(:glob)
          prefix        = options[:prefix]
          ignore_hidden = options[:ignore_hidden]

          files = Dir[glob]
          files.reject! { |f| f.start_with?('.') } if ignore_hidden

          dest = prefix ? File.join(tmpdir, prefix) : tmpdir

          FileUtils.mkpath(dest)
          FileUtils.cp_r(files, dest)
        end

        excludes.each do |path|
          full_path = File.join(tmpdir, path)
          if File.file?(full_path)
            File.unlink(File.join(tmpdir, path))
          end
        end

        # Specify the correct ruby version in the Dockerfile.
        bundle_dockerfile = File.join(tmpdir, "Dockerfile")
        content = IO.read(bundle_dockerfile)
        content = content.gsub("{{ruby_version}}", ruby_version)
        IO.write bundle_dockerfile, content

        if dockerfile
          File.unlink bundle_dockerfile
          FileUtils.cp dockerfile, bundle_dockerfile
        end

        # Find hash of all files we're sending over.
        digest = Digest::SHA1.new
        Dir[File.join(tmpdir, '**/*')].each do |path|
          if File.file? path
            open path, 'r' do |file|
              digest.update file.read
            end
          end
        end
        @image_name = "hoosegow:#{digest.hexdigest}"

        # Create tarball of the tmpdir.
        stdout, stderr, status = Open3.capture3 'tar', '-c', '-C', tmpdir, '.'

        raise Hoosegow::ImageBuildError, stderr unless stderr.empty?

        @tarball = stdout
      end
    end

    private

    # The things to include in the tarfile.
    def definition
      @definition ||= []
    end

    # The things to exclude from the tarfile
    def excludes
      @excludes ||= []
    end
  end
end
