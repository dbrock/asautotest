require "socket"
require "timeout"
require "rexml/document"

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

      @n_planned_tests = nil
      @n_completed_tests = 0
      @n_failed_tests = 0
    end

    def run
      whisper "Running tests via socket connection."
      with_server_running { run_test }
    rescue TestMisbehaving
      shout "Terminating misbehaving test."
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
      if failed_tests?
        puts
      else
        say test_count_report
        shout "Missing #{n_missing_tests} tests." if missing_tests?
      end
    end

    def test_count_report
      build_string do |result|
        result << "Ran #{n_completed_tests} tests"

        if new_tests?
          result << " (#{n_new_tests} new)"
        elsif missing_tests?
          result << " (too few)"
        end

        result << " in ~#@compilation_stopwatch + ~#@test_stopwatch seconds."
      end
    end

    def talk_patiently_to_test
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
          when /^xml-result: (.*)/
            begin
              interpret_result(Result.parse_xml($1))
            rescue Result::ParseError
              misbehavior! "Could not interpret XML result: #$1"
            end
          else
            puts ">> #{line.inspect}"
          end
        end
      end
    end

    def interpret_result(result)
      @n_completed_tests += 1
      @n_failed_tests += 1 if not result.passed?
      result.report!
    end

    class Result
      class ParseError < Exception ; end

      include Logging

      attr_reader :test_name

      def initialize(test_name)
        @test_name = test_name
      end

      def self.parse_xml(input)
        XMLResult.new(REXML::Document.new(input).root).result
      #rescue
      #  raise ParseError
      end
      
      class XMLResult
        def initialize(root)
          @root = root
        end

        def result
          case @root.name
          when "success"
            Success.new(test_name)
          when "failure"
            failure
          else
            raise ParseError
          end
        end

        def test_name
          @root.attributes["test-name"] or raise ParseError
        end

        def failure
          case failure_type
          when "equality"
            Failure::Equality.new \
              test_name,
              failure_attribute("expected"),
              failure_attribute("actual")
          else
            Failure::Simple.new(test_name, description)
          end
        end

        def failure_type
          failure_element.name if failure_element
        end

        def description
          @root.attributes["description"]
        end

        def failure_attribute(name)
          failure_element.attributes[name] or raise ParseError
        end

        def failure_element
          @root.elements[1]
        end
      end

      class Success < Result
        def passed? ; true end

        def report!
          whisper "Passed: #{test_name}"
        end
      end

      class Failure < Result
        def passed? ; false end

        def report!
          test_name =~ /^(.*?)(?: \((\S+)\))?$/
          puts
          print ljust("\e[1;31mFailed:\e[0m \e[1;4m#$1\e[0m  ", 50)
          print "(\e[4m#$2\e[0m)" if $2
          puts
          report_reason!
        end

        def report_reason! ; end

        class Simple < Failure
          def initialize(test_name, description)
            super(test_name)
            @description = description
          end

          def report_reason!
            puts "  #@description" if @description
          end
        end

        class Equality < Failure
          def initialize(test_name, expected, actual)
            super(test_name)
            @expected = expected
            @actual = actual
          end

          def report_reason!
            puts "  \e[1mExpected:\e[0m  \e[0m#@expected\e[0m"
            puts "  \e[1mActual:\e[0m    \e[0m#@actual\e[0m"
          end
        end
      end
    end

    # ------------------------------------------------------

    attr_reader :n_planned_tests
    attr_reader :n_completed_tests
    attr_reader :n_failed_tests

    def n_missing_tests
      n_planned_tests - n_completed_tests
    end

    def n_new_tests
      n_completed_tests - n_planned_tests
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
  end
end
