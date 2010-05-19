require "socket"
require "open4"

module ASAutotest
  class TestRunner
    class TestMisbehaving < Exception ; end

    include Logging

    EXPECTED_GREETING = "Hello, this is a test.\n"
    POLICY_FILE_REQUEST = "<policy-file-request/>\0"
  
    # Make sure we can accept a policy file request as a greeting.
    EXPECTED_GREETING.size >= POLICY_FILE_REQUEST.size or
      raise "Internal error: Expected greeting is too short."

    PORT = 50002

    def initialize(binary_name, compilation_stopwatch)
      @binary_name = binary_name
      @compilation_stopwatch = compilation_stopwatch
    end

    def run
      whisper "Running tests via socket connection."
      with_server_running { run_test }
    rescue TestMisbehaving
      # Problems will already have been reported here,
      # so we don't have to do anything more.
    end

    def run_test
      with_flash_running do
        accept_connection
        shake_hands
        talk_to_test
      end
    end

    # ------------------------------------------------------

    def with_server_running
      start_server
      begin
        yield
      ensure
        stop_server
      end
    end

    def start_server
      @server = TCPServer.new(PORT)
      @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    end

    def stop_server
      @server.close
    end

    # ------------------------------------------------------

    def with_flash_running
      start_flash
      begin
        yield
      ensure
        stop_flash
      end
    end

    def start_flash
      @flash_pid = fork { exec FLASHPLAYER, @binary_name }
    end

    def stop_flash
      Process.kill("TERM", @flash_pid)
      Process.wait(@flash_pid)
    end

    # ------------------------------------------------------

    def misbehavior!(*descriptions)
      print_warnings(descriptions)
      raise TestMisbehaving
    end

    def print_warnings(warnings)
      for warning in warnings do
        shout warning
      end
    end

    # ------------------------------------------------------

    def accept_connection
      whisper "Accepting connection" do
        # It takes at least 3 seconds to get a policy file request.
        @socket = Timeout.timeout(4) { @server.accept }
      end
    rescue Timeout::Error
      misbehavior! "Test did not connect to localhost:#{PORT}."
    end

    def shake_hands
      Timeout.timeout(1) { parse_greeting(read_greeting) }
    rescue Timeout::Error
      misbehavior! "Handshake took too long."
    end

    def read_greeting
      @socket.read(EXPECTED_GREETING.size)
    end

    def parse_greeting(greeting)
      case greeting
      when EXPECTED_GREETING
        whisper "Performed handshake."
      when nil
        misbehavior! "Test closed connection without sending anything."
      when POLICY_FILE_REQUEST
        misbehavior! \
          "Recieved policy file request; aborting.",
          "Please set up a policy server on port 843."
      else
        misbehavior! "Unrecognized greeting: #{greeting.inspect}"
      end
    end

    def talk_to_test
      @test_stopwatch = Stopwatch.new
      Timeout.timeout(10) { talk_patiently_to_test }
      report_results
    rescue Timeout::Error
      misbehavior! "Test run taking too long; aborting."
    end

    def report_results
      say test_count_report

      shout "Missing #{n_missing_tests} tests." if missing_tests?
      shout "Failures in #{n_failed_tests} tests." if failed_tests?
    end

    def new_tests?
      n_new_tests > 0
    end

    def missing_tests?
      n_missing_tests > 0
    end

    def failed_tests?
      n_failed_tests > 0
    end

    def n_missing_tests
      n_planned_tests - n_completed_tests
    end

    def n_new_tests
      n_completed_tests - n_planned_tests
    end

    attr_reader :n_planned_tests
    attr_reader :n_completed_tests
    attr_reader :n_failed_tests

    def test_count_report
      build_string do |result|
        result << "Ran #@n_completed_tests tests"

        if @n_completed_tests > @n_planned_tests
          result << " (#{@n_completed_tests - @n_planned_tests} new)"
        elsif @n_completed_tests < @n_planned_tests
          result << " (too few)"
        end

        result << " in ~#@compilation_stopwatch + ~#@test_stopwatch seconds."
      end
    end

    def talk_patiently_to_test
      @n_planned_tests = nil
      @n_completed_tests = 0
      @n_failed_tests = 0
      catch(:done) do
        loop do
          line = @socket.readline.chomp
          case line
          when /^plan (\d+)$/
            if @n_planned_tests != nil
              misbehavior! "Got another plan: #{line.inspect}"
            elsif @n_completed_tests > 0
              misbehavior! "Got plan too late: #{line.inspect}"
            else
              @n_planned_tests = $1.to_i
              whisper "Planning to run #{@n_planned_tests} tests."
            end
          when "done"
            throw :done
          when /^passed: (.*)/
            whisper "Passed: #$1"
            @n_completed_tests += 1
          when /^failed: (.*)/
            shout "Failed: #$1"
            @n_completed_tests += 1
            @n_failed_tests += 1
          when /^reason: (.*)/
            shout "Reason: #$1"
          else
            puts ">> #{line.inspect}"
          end
        end
      end
    end
  end
end
