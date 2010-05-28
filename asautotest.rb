require "rubygems"
require "pathname"
require "logging"
require "stopwatch"
require "compiler-shell"
require "compilation-runner"
require "test-runner"
require "utilities"
require "comet-server"

module ASAutotest
  WATCH_GLOB = "**/[^.]*.{as,mxml}"
  MXMLC = "/Users/daniel/Downloads/flex-4-sdk/bin/mxmlc"
  FCSH = "/Users/daniel/Downloads/flex-4-sdk/bin/fcsh"
  FLASHPLAYER = "/Applications/Flash Player.app/Contents/MacOS/Flash Player"
  TEST_PORT = 50102
  COMET_PORT = 50103

  class Main
    include Logging

    def initialize(test_source_file_name, *source_directories)
      @source_directories = source_directories.map do |directory_name|
        File.expand_path(directory_name) + "/"
      end
      @test_source_file_name = File.expand_path(test_source_file_name)
    end

    def run
      print_header
      start_comet_server
      start_compiler_shell
      build
      monitor_changes
    end

    def print_header
      new_logging_section

      say "Root test: ".ljust(20) + @test_source_file_name

      for source_directory in @source_directories do
        say "Source directory: ".ljust(20) + source_directory
      end

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
        :input_file_name => @test_source_file_name,
        :output_file_name => @test_binary_file_name
      @compiler_shell.start
    end
  
    def monitor_changes
      require "fssm"
      monitor = FSSM::Monitor.new
      each_source_directory do |source_directory|
        monitor.path(source_directory, WATCH_GLOB) do |watch|
          watch.update { |base, relative| handle_change }
          watch.create { |base, relative| handle_change }
          watch.delete { |base, relative| handle_change }
        end
      end
      monitor.run
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
        run_tests if @compilation.did_anything?
        delete_test_binary
      end

      whisper "Ready."
      @comet_pipe.puts
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
      "/tmp/asautotest/#{get_timestamp}-#{rand}.swf"
    end

    def get_timestamp
      (Time.new.to_f * 100).to_i
    end
  end
end

$normal_arguments = []
$verbose = false

for argument in ARGV do
  case argument
  when "--verbose"
    $verbose = true
  when /^-/
    warn "unrecognized argument: #{argument}"
  else
    $normal_arguments << argument
  end
end

ASAutotest::Logging.verbose = $verbose
ASAutotest::Main.new(*$normal_arguments).run
