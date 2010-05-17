require "socket"

class PolicyFileServer
  PORT = 843

  def initialize
    @server = TCPServer.new(PORT)
    @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

    puts "Listening to port #{PORT}."
  end

  def run
    Thread.abort_on_exception = true
    loop { accept }
  end

  def accept
    socket = @server.accept
    handle_socket(socket)
    socket.close
    puts "Closed socket."
  end

  def handle_socket(socket)
    source = "#{socket.peeraddr[2]}:#{socket.peeraddr[1]}"
    puts "Recieved connection from #{source}."

    expected_line = "<policy-file-request/>\0"

    line = socket.read(expected_line.size)

    if line == expected_line
      socket.print(File.open("cross-domain-policy.xml").read)
      socket.print("\0")
      puts "Sent policy file to #{source}."
    else
      warn "Recieved garbage from #{source}: #{line.inspect}"
    end
  end

  def response
    '<?xml version="1.0"?>' +
      '<!DOCTYPE cross-domain-policy SYSTEM "/xml/dtds/cross-domain-policy.dtd">' +
      '<cross-domain-policy>' +
      '<site-control permitted-cross-domain-policies="master-only"/>' +
      '<allow-access-from domain="*" to-ports="*"/>' +
      '</cross-domain-policy>' +
      "\0"
  end
end

PolicyFileServer.new.run
