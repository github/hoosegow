require 'net/http'
require 'json'
require 'uri'

class Hoosegow
  # Minimal API client for Docker, allowing attaching to container
  # stdin/stdout/stderr.
  class Docker
    def initialize(host, port, image)
      @host   = host
      @port   = port
      @create = JSON.dump :StdinOnce => true, :OpenStdin => true, :image => image
      @attach = {:stdout => 1, :stderr => 1, :stdin => 1, :logs => 0, :stream => 1}
    end

    # Internal: Similar to `echo input | docker run -t=image`
    def run(input)
      res = post uri(:create), @create
      id  = JSON.load(res)["Id"]
      res = post uri(:attach, id, @attach), input do
        post uri(:start, id)
      end
      post uri(:wait, id)
      delete uri(:delete, id)
      res
    end

    private
    def post(uri, data = '{}')
      headers = {"Content-Type" => "application/json"}
      request = Net::HTTP::Post.new uri, headers

      Net::HTTP.start @host, @port do |http|
        if block_given?
          # Abort the request to keep the socket open.
          http.request request do |response|
            response.instance_variable_set '@skip', true
          end
          yield
          sock = http.instance_variable_get '@socket'
          sock.io.write data
          sock.io.close_write
          sock.io.read
        else
          http.request(request, data).body
        end
      end
    end

    def delete(uri)
      Net::HTTP.start @host, @port do |http|
        http.delete uri
      end
    end

    def uri(endpoint, *args)
      query = URI.encode_www_form( args.last.is_a?(Hash) ? args.pop : {} )
      path  = {:create => "/containers/create",
               :attach => "/containers/%s/attach",
               :start  => "/containers/%s/start",
               :wait   => "/containers/%s/wait",
               :delete => "/containers/%s"}[endpoint]
      path  = sprintf path, *args
      
      URI::HTTP.build(:path => path, :query => query).request_uri
    end
  end
end

module Net
  class HTTPResponse
    alias_method :_body, :body
    def body
      defined?(@skip) ? return : _body
    end
  end
end

