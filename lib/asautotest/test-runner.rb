# -*- coding: utf-8 -*-
# test-runner.rb --- run tests and report the results
# Copyright (C) 2010  Go Interactive

# This file is part of ASAutotest.

# ASAutotest is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# ASAutotest is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with ASAutotest.  If not, see <http://www.gnu.org/licenses/>.

require "socket"
require "timeout"
require "rexml/document"

module ASAutotest
  class TestRunner
    class TestMisbehaving < Exception ; end
    class TestMisbehavingFatally < Exception ; end

    include Logging

    EXPECTED_GREETING = "Hello, this is a test.\n"
    POLICY_FILE_REQUEST = "<policy-file-request/>\0"
  
    # Make sure we can accept a policy file request as a greeting.
    EXPECTED_GREETING.size >= POLICY_FILE_REQUEST.size or
      raise "Internal error: Expected greeting is too short."

    def initialize(binary_name, port)
      @binary_name = binary_name
      @port = port
      @n_planned_tests = nil
      @suites = {}
    end

    def run
      whisper "Running tests via socket connection."
      with_server_running { run_test }
    rescue TestMisbehaving
      shout "Terminating misbehaving test."
    rescue TestMisbehavingFatally
      exit
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
      @server = TCPServer.new(@port)
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

    def fatal_misbehavior!(*descriptions)
      print_warnings(descriptions)
      raise TestMisbehavingFatally
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
      misbehavior! "Test did not connect to localhost:#@port."
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
        fatal_misbehavior! \
          "Recieved cross-domain policy file request; aborting.",
          "Please run a policy server on port 843 (root usually needed).",
          "See ‘bin/policy-server.rb’ in the ASAutotest distribution."
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
        suites.each &:print_report!
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

        result << " in ~#@test_stopwatch seconds."
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
            elsif n_completed_tests > 0
              misbehavior! "Got plan too late: #{line.inspect}"
            else
              @n_planned_tests = $1.to_i
              whisper "Planning to run #{@n_planned_tests} tests."
            end
          when "done"
            throw :done
          when /^xml-result: (.*)/
            begin
              result = Result.parse_xml($1)
              get_suite(result.suite_name) << result
            rescue Result::ParseError
              misbehavior! "Could not interpret XML result: #$1"
            end
          else
            puts ">> #{line.inspect}"
          end
        end
      end
    end

    def n_completed_tests
      suites.map(&:n_results).sum
    end

    def n_failed_tests
      suites.map(&:n_failures).sum
    end

    def suites
      @suites.values
    end

    def get_suite(name)
      if @suites.include? name
        @suites[name]
      else
        @suites[name] = Suite.new(name)
      end
    end

    class Suite
      attr_reader :name

      def initialize(name)
        @name = name
        @results = []
      end

      def << result
        @results << result
      end

      def print_report!
        if @results.any? &:failed?
          print_header!
          @results.each &:print_report!
        end
      end

      def print_header!
        puts
        puts "\e[1m#{display_name}\e[0m"
      end

      def display_name
        @name or "(Unnamed suite)"
      end

      def n_results
        @results.size
      end

      def n_failures
        @results.count &:failed?
      end
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
      rescue
        raise ParseError
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

      def passed? ; not failed? end

      def local_name
        local_and_suite_names[1]
      end

      def suite_name
        local_and_suite_names[2]
      end

      def local_and_suite_names
        test_name.match /^(.*?)(?: \((\S+)\))?$/
      end

      class Success < Result
        def failed? ; false end

        def print_report!
          whisper "Passed: #{test_name}"
        end
      end

      class Failure < Result
        def failed? ; true end

        def print_report!
          puts "  \e[1;31mFailed:\e[0m \e[0;4m#{local_name}\e[0m"
          report_reason!
        end

        def report_reason! ; end

        class Simple < Failure
          def initialize(test_name, description)
            super(test_name)
            @description = description
          end

          def report_reason!
            puts "    \e[0m#@description\e[0m" if @description
          end
        end

        class Equality < Failure
          def initialize(test_name, expected, actual)
            super(test_name)
            @expected = expected
            @actual = actual
          end

          def report_reason!
            puts "    \e[0mActual:\e[0m    \e[0m#@actual\e[0m"
            puts "    \e[0mExpected:\e[0m  \e[0m#@expected\e[0m"
          end
        end
      end
    end

    # ------------------------------------------------------

    attr_reader :n_planned_tests

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
