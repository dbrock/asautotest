require "socket"

class WebServer
  def initialize
    @server = TCPServer.new(8080)
    @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
  end

  def run
    loop { handle_request(@server.accept) }
  end

  def handle_request(socket)
    Thread.new(socket) do |socket|
      Handler.new(socket).run
    end
  end

  class Handler
    def initialize(socket)
      @socket = socket
    end

    def run
      @socket.puts "HTTP/1.0 204"
      @socket.close
    end
  end
end

WebServer.new.run
