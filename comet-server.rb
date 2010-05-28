require "socket"

module ASAutotest
  class CometServer
    def initialize(port, pipe)
      @server = TCPServer.new(port)
      @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      @mutex = Mutex.new
      @variable = ConditionVariable.new
      @pipe = pipe
    end
  
    def run
      Thread.new { loop { accept } }
      @pipe.each_line { @variable.broadcast }
    end

    def accept
      Handler.new(@mutex, @variable, @server.accept).start
    end

    class Handler
      def initialize(mutex, variable, socket)
        @mutex = mutex
        @variable = variable
        @socket = socket
      end
  
      def start
        Thread.new { run }
      end
  
      def run
        @mutex.synchronize { @variable.wait(@mutex) }
        @socket.puts "HTTP/1.0 204"
        @socket.close
      end
    end
  end
end
