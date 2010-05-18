require "socket"
require "open4"

module ASAutotest
  class TestRunner
    include Logging

    def initialize(binary_name)
      @binary_name = binary_name
    end
  
    def run
      info "Running tests via socket connection."
      expected_greeting = "Hello, this is a test.\n"
      policy_file_request = "<policy-file-request/>\0"
  
      # Make sure we can accept a policy file request as a greeting.
      unless expected_greeting.size >= policy_file_request.size
        raise "Internal error: Expected greeting is too short."
      end
      
      port = 50002
      server = TCPServer.new(port)
      server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      Open4.popen4(FLASHPLAYER, @binary_name) do |pid, stdin, stdout, stderr|
        begin
          begin_info "Accepting connection"
          # It takes at least 3 seconds to get a policy file request.
          socket = Timeout.timeout(5) { server.accept }
          end_info "ok"
          begin
            Timeout.timeout(10) do
              greeting = socket.read(expected_greeting.size)
              case greeting
              when nil
                info "!! Test closed connection without sending anything."
              when policy_file_request
                info "!! Recieved policy file request; aborting."
                info "!! Please set up a policy server on port 843."
              when expected_greeting
                info "Performed handshake."
                catch(:done) do
                  loop do
                    line = socket.readline.chomp
                    case line
                    when "done"
                      info "Test run successful."
                      throw :done
                    when /^passed: (.*)/
                      info "Passed: #$1"
                    when /^failed: (.*)/
                      info "!! Failed: #$1"
                    when /^reason: (.*)/
                      info "!! Reason: #$1"
                    else
                      puts ">> #{line.inspect}"
                    end
                  end
                end
              else
                info "!! Unrecognized greeting: #{greeting.inspect}"
              end            
            end
          rescue Timeout::Error
            info "!! Test run taking too long; aborting."
          end
        rescue Timeout::Error
          end_info "timeout"
          info "!! Test did not connect to localhost:#{port}."
        end
  
        server.close
  
        if Open4.alive? pid
          begin_info "Killing process"
          Open4.maim(pid, :suspend => 0.5)        
          end_info(Open4.alive?(pid) ? "ok" : "failed")
        end
      end
    end
  end
end
