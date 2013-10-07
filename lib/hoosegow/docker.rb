require 'net/http'
require 'socket'
require 'json'
require 'uri'

class Hoosegow
  # Minimal API client for Docker, allowing attaching to container
  # stdin/stdout/stderr.
  class Docker
    # Internal: Initialize a new Docker API client.
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

    # Internal: Similar to `echo input | docker run -t=image`
    #
    # image - The name of the image to run.
    # input - The data to pipe to the container's stdin.
    #
    # Returns the data from the container's stdout.
    def run(image, input)
      create = JSON.dump :StdinOnce => true, :OpenStdin => true, :image => image
      res    = post uri(:create), create
      id     = JSON.load(res)["Id"]

      post uri(:start, id)

      attach = {:stdout => 1, :stderr => 1, :stdin => 1, :logs => 1, :stream => 1}
      res    = post uri(:attach, id, attach), input, true

      post uri(:wait, id)
      delete uri(:delete, id)
      res.gsub /\n\z/, ''
    end

    # Internal: Build a new image.
    #
    # image   - The name of the image to create.
    # tarfile - Tarred data for creating image. See http://docs.docker.io/en/latest/api/docker_remote_api_v1.5/#build-an-image-from-dockerfile-via-stdin
    #
    # Returns build results.
    def build(image, tarfile)
      post uri(:build, :t => image), tarfile
    end

    private
    # Private: Send a POST request to the API.
    #
    # uri    - API URI to POST to.
    # data   - Data for POST body.
    # stream - Hijack the HTTP connection's socket and shutdown writing after
    #          sending the data.
    #
    # Returns the response body.
    def post(uri, data = '{}', stream = false)
      headers = {"Content-Type" => "application/json"}
      request = Net::HTTP::Post.new uri, headers
      transport_request request, data, stream
    end

    # Private: Send a DELETE request to the API.
    #
    # uri    - API URI to POST to.
    #
    # Returns the response body.
    def delete(uri)
      headers = {"Content-Type" => "application/json"}
      request = Net::HTTP::Delete.new uri, headers
      transport_request request
    end

    # Private: Connects to API host or local socket, transmits the request, and
    # reads in the response.
    #
    # request - A Net::HTTPResponse object without a body set.
    # data    - Data to be used as body for POST requests.
    # stream  - Hijack the HTTP connection's socket and shutdown writing after
    #           sending the data.
    #
    # Returns the response body.
    def transport_request(request, data = '{}', stream = false)
      socket       = new_socket
      socket.io.reopen(socket.io)
      request.body = data unless stream
      request.exec socket, "1.1", request.path

      begin
        response = Net::HTTPResponse.read_new(socket)
      end while response.kind_of?(Net::HTTPContinue)

      socket.write(data + "\n") if stream

      response.reading_body(socket, request.response_body_permitted?) { }
      body = response.body
      body
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
