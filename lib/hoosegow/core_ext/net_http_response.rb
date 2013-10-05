require 'net/http'

# Patch HTTPResponse to return before attempting to read the response body and
# close the socket.
module Net
  class HTTPResponse
    alias_method :_body, :body
    def body
      defined?(@skip) ? return : _body
    end
  end
end