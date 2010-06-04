require "socket"
require "timeout"

class PolicyFileServer
  PORT = 843

  def initialize
    @server = TCPServer.new(PORT)
    @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

    info "Listening to localhost:#{PORT}."
  end

  def run
    loop { accept }
  end

  def accept
    handle_socket(@server.accept)
  end

  def info(message)
    puts info_string(message)
  end

  def info_string(message)
    "policy-file-server: #{message}"
  end

  def begin_info(message)
    STDOUT.print info_string("#{message}...")
    STDOUT.flush
  end

  def end_info(message)
    STDOUT.puts " #{message}."
  end

  EXPECTED_REQUEST = "<policy-file-request/>\0"

  def handle_socket(socket)
    source = "#{socket.peeraddr[2]}:#{socket.peeraddr[1]}"
    begin_info "Serving #{source}"
    request = Timeout.timeout(3) { socket.read(EXPECTED_REQUEST.size) }
    if request == EXPECTED_REQUEST
      socket.print(policy_xml)
      socket.print("\0")
      end_info "ok"
    else
      end_info "recieved garbage: #{request.inspect}"
    end
  rescue Timeout::Error
    end_info "timeout"
  ensure
    socket.close
  end

  def policy_xml
    <<-end_xml
      <cross-domain-policy>
        <site-control permitted-cross-domain-policies="master-only"/>
        <allow-access-from domain="*" to-ports="*"/>
      </cross-domain-policy>
    end_xml
  end
end

PolicyFileServer.new.run
