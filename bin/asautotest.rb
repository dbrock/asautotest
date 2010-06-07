#!/usr/bin/env ruby

require "rubygems"
require "pathname"

$: << File.join(File.dirname(Pathname.new(__FILE__).realpath), "..", "lib")

require "asautotest/logging"
require "asautotest/stopwatch"
require "asautotest/compiler-shell"
require "asautotest/compilation-runner"
require "asautotest/test-runner"
require "asautotest/utilities"
require "asautotest/comet-server"

module ASAutotest
  WATCH_GLOB = "**/[^.]*.{as,mxml}"
  MXMLC = "/Users/daniel/Downloads/flex-4-sdk/bin/mxmlc"
  FCSH = "/Users/daniel/Downloads/flex-4-sdk/bin/fcsh"
  FLASHPLAYER = "/Applications/Flash Player.app/Contents/MacOS/Flash Player"
  TEST_PORT = 50102
  COMET_PORT = 50103

  class Main
    include Logging

    def initialize(test_source_file_name, source_directories, options)
      @source_directories = source_directories.map do |directory_name|
        File.expand_path(directory_name) + "/"
      end
      @test_source_file_name = File.expand_path(test_source_file_name)
      @no_test = options[:no_test?]
      @output_file_name = File.expand_path(options[:output_file_name]) if
        options[:output_file_name]
      @library_path = options[:library_path].map do |file_name|
        File.expand_path(file_name)
      end
    end

    def self.run(*arguments)
      new(*arguments).run
    end

    def run
      print_header
      # start_comet_server
      start_compiler_shell
      build
      monitor_changes
    end

    def print_header
      new_logging_section

      say "Source file: ".ljust(20) + @test_source_file_name

      for source_directory in @source_directories do
        say "Source directory: ".ljust(20) + source_directory
      end

      for library in @library_path do
        say "Library: ".ljust(20) + library
      end

      say "Not running any tests." if @no_test
      say "Running in verbose mode." if Logging.verbose?

      new_logging_section
    end

    def start_comet_server
      read_pipe, @comet_pipe = IO.pipe
      fork do
        @comet_pipe.close
        CometServer.new(COMET_PORT, read_pipe).run
      end
      read_pipe.close
    end

    def start_compiler_shell
      @test_binary_file_name = get_test_binary_file_name
      @compiler_shell = CompilerShell.new \
        :source_directories => @source_directories,
        :library_path => @library_path,
        :input_file_name => @test_source_file_name,
        :output_file_name => @test_binary_file_name
      @compiler_shell.start
    end

    def monitor_changes
      user_wants_out = false

      Signal.trap("INT") do
        user_wants_out = true
        throw :asautotest_interrupt
      end
      
      until user_wants_out
        require "fssm"
        monitor = FSSM::Monitor.new
        each_source_directory do |source_directory|
          monitor.path(source_directory, WATCH_GLOB) do |watch|
            watch.update { handle_change }
            watch.create { handle_change ; throw :asautotest_interrupt }
            watch.delete { handle_change ; throw :asautotest_interrupt }
          end
        end
        catch :asautotest_interrupt do
          monitor.run
        end
      end
    end

    def each_source_directory(&block)
      @source_directories.each(&block)
    end

    def handle_change
      new_logging_section
      whisper "Change detected."
      build
    end

    def build
      compile

      if @compilation.successful?
        run_tests if @compilation.did_anything? unless @no_test
        delete_test_binary unless @no_test
      end

      whisper "Ready."
      # @comet_pipe.puts
    end

    def compile
      @compilation = CompilationRunner.new(@compiler_shell)
      @compilation.run
    end

    def run_tests
      TestRunner.new(@test_binary_file_name).run
    end

    def delete_test_binary
      begin
        File.delete(@test_binary_file_name)
        whisper "Deleted binary."
      rescue Exception => exception
        shout "Failed to delete binary: #{exception.message}"
      end
    end

    def get_test_binary_file_name
      @output_file_name ||
        "/tmp/asautotest/#{get_timestamp}-#{rand}.swf"
    end

    def get_timestamp
      (Time.new.to_f * 100).to_i
    end
  end
end

$normal_arguments = []
$verbose = false
$no_test = false
$output_file_name = nil
$library_path = []

for argument in ARGV do
  case argument
  when "--verbose"
    $verbose = true
  when "--no-test"
    $no_test = true
  when /--output=(\S+)/
    $output_file_name = $1
  when /--library=(\S+)/
    $library_path << $1
  when /^-/
    warn "unrecognized argument: #{argument}"
  else
    $normal_arguments << argument
  end
end

unless $normal_arguments.size >= 2
  warn "usage: asautotest [OPTIONS...] SOURCE-FILE SOURCE-DIRS..."
  exit -1
end

ASAutotest::Logging.verbose = $verbose
ASAutotest::Main.run \
  $normal_arguments[0],
  $normal_arguments[1..-1],
  :no_test? => $no_test,
  :output_file_name => $output_file_name,
  :library_path => $library_path
