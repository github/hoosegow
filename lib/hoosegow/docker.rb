require 'net/http'
require 'socket'
require 'json'
require 'uri'

class Hoosegow
  # Minimal API client for Docker, allowing attaching to container
  # stdin/stdout/stderr.
  class Docker
    HEADERS = {"Content-Type" => "application/json"}

    # Initialize a new Docker API client.
    #
    # options - Connection options.
    #           :host   - IP or hostname to connect to (unless using Unix
    #                     socket).
    #           :port   - TCP port to connect to (unless using Unix socket).
    #           :socket - Path to local Unix socket (unless using host and
    #                     port).
    def initialize(options = {})
      if options[:host] || options[:port]
        @host   = options[:host] || "127.0.0.1"
        @port   = options[:port] || 4243
      else
        @socket_path = options[:socket] || "/var/run/docker.sock"
      end
    end

    # Public: Create and start a Docker container if one hasn't been started
    # already, then attach to it its stdin/stdout.
    #
    # data - The data to pipe to the container's stdin.
    #
    # Returns the data from the container's stdout.
    def run(data)
      # Start a container if one isn't running yet.
      start_container unless @id

      # Attach to container.
      params  = {:stdout => 1, :stderr => 1, :stdin => 1, :logs => 1, :stream => 1}
      request = Net::HTTP::Post.new uri(:attach, @id, params), HEADERS
      res     = transport_request request, data

      # Wait for the container to finish
      post uri(:wait, @id)

      # Delete the container
      delete = Net::HTTP::Delete.new uri(:delete, @id), HEADERS
      transport_request delete

      # Start a container for the next run.
      start_container
      
      res.gsub /\n\z/, ''
    end

    # Public: Build a new image.
    #
    # tarfile - Tarred data for creating image. See http://docs.docker.io/en/latest/api/docker_remote_api_v1.5/#build-an-image-from-dockerfile-via-stdin
    #
    # Returns build results.
    def build(tarfile)
      post uri(:build, :t => 'hoosegow'), tarfile
    end

    private
    # Public: Create and start a Docker container.
    #
    # Returns nothing.
    def start_container
      # Create container.
      create_body = JSON.dump :StdinOnce => true, :OpenStdin => true, :image => 'hoosegow'
      res         = post uri(:create), create_body
      @id         = JSON.load(res)["Id"]

      # Start container
      post uri(:start, @id)
    end

    # Private: Send a POST request to the API.
    #
    # uri    - API URI to POST to.
    # data   - Data for POST body.
    #
    # Returns the response body.
    def post(uri, data = '{}')
      request = Net::HTTP::Post.new uri, HEADERS
      request.body = data
      transport_request request
    end

    # Private: Connects to API host or local socket, transmits the request, and
    # reads in the response.
    #
    # request - A Net::HTTPResponse object without a body set.
    #
    # Returns the response body.
    def transport_request(request, data = nil)
      request = request
      socket  = new_socket
      request.exec socket, "1.1", request.path

      begin
        response = Net::HTTPResponse.read_new(socket)
      end while response.kind_of?(Net::HTTPContinue)

      socket.write(data) if data
      response.reading_body(socket, request.response_body_permitted?) { }
      response.body
    end

    # Private: Create a connection to API host or local Unix socket.
    #
    # Returns Net::BufferedIO socket object.
    def new_socket
      socket = if @socket_path
                 UNIXSocket.new(@socket_path)
               else
                 TCPSocket.open @host, @port
               end
      Net::BufferedIO.new socket
    end

    # Private: Build a URI for a given API endpount, encorporating any
    # arguments or parameters.
    #
    # endpoint - The Symbol name for an API endpoint (:create, :attach, :start,
    #            :wait, :delete, :build).
    # *args    - Any arguments for building the URI (container ID). If the last
    #            argument is a hash, it will be used to populate the query
    #            portion of the URI.
    #
    # Returns a URI string.
    def uri(endpoint, *args)
      query = URI.encode_www_form( args.last.is_a?(Hash) ? args.pop : {} )
      path  = {:create => "/containers/create",
               :attach => "/containers/%s/attach",
               :start  => "/containers/%s/start",
               :wait   => "/containers/%s/wait",
               :delete => "/containers/%s",
               :build  => "/build"}[endpoint]
      path  = sprintf path, *args
      
      URI::HTTP.build(:path => path, :query => query).request_uri
    end
  end
end
