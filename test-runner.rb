require "socket"
require "open4"

module ASAutotest
  class TestRunner
    include Logging

    def initialize(binary_name)
      @binary_name = binary_name
    end
  
    def run
      verbose_info "Running tests via socket connection."
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
          verbose_begin_info "Accepting connection"
          # It takes at least 3 seconds to get a policy file request.
          socket = Timeout.timeout(5) { server.accept }
          verbose_end_info "ok"
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
                verbose_info "Performed handshake."
                catch(:done) do
                  plan = nil
                  n_ran_tests = 0
                  n_failed_tests = 0
                  loop do
                    line = socket.readline.chomp
                    case line
                    when /^plan (\d+)$/
                      if plan != nil
                        info "!! Got another plan: #{line.inspect}"
                      elsif n_ran_tests > 0
                        info "!! Got plan too late: #{line.inspect}"
                      else
                        plan = $1.to_i
                        verbose_info "Planning to run #{plan} tests."
                      end
                    when "done"
                      if n_ran_tests == plan
                        info "Ran #{n_ran_tests} tests."
                      elsif n_ran_tests > plan
                        info "Ran #{n_ran_tests} tests " +
                          "(#{n_ran_tests - plan} new)."
                      else
                        info "Ran #{n_ran_tests} tests " +
                          "but planned for #{plan}."
                        info "!! Missing #{plan - n_ran_tests} tests!"
                      end

                      if n_failed_tests > 0
                        info "!! Failures in #{n_failed_tests} tests."
                      end

                      throw :done
                    when /^passed: (.*)/
                      verbose_info "Passed: #$1"
                      n_ran_tests += 1
                    when /^failed: (.*)/
                      info "!! Failed: #$1"
                      n_ran_tests += 1
                      n_failed_tests += 1
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
          verbose_end_info "timeout"
          info "!! Test did not connect to localhost:#{port}."
        end
  
        server.close

        Open4.maim(pid, :suspend => 0.5)
      end
    end
  end
end
