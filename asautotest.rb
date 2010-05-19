require "rubygems"
require "fssm"
require "logging"
require "stopwatch"
require "compilation-runner"
require "test-runner"

module ASAutotest
  WATCH_GLOB = "**/[^.]*.{as,mxml}"
  MXMLC = "/Users/daniel/Downloads/flex-4-sdk/bin/mxmlc"
  FLASHPLAYER = "/Applications/Flash Player.app/Contents/MacOS/Flash Player"

  class Main
    include Logging

    def initialize(test_source_file_name, *source_directories)
      @source_directories = source_directories
      @test_source_file_name = test_source_file_name
    end

    def run
      print_header
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
  
    def monitor_changes
      monitor = FSSM::Monitor.new
      each_source_directory do |source_directory|
        monitor.path(source_directory, WATCH_GLOB) do |watch|
          watch.update do |base, relative|
            handle_change
          end
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

      if compilation_successful?
        run_tests
        delete_test_binary
      end

      whisper "Ready."
    end

    def compile
      @compilation_stopwatch = Stopwatch.new
      @test_binary_file_name = get_test_binary_file_name
      @compilation = CompilationRunner.new \
        :source_directories => @source_directories,
        :input_file_name => @test_source_file_name,
        :output_file_name => @test_binary_file_name
      @compilation.run
      @compilation_stopwatch.stop
    end

    def compilation_successful?
      @compilation.successful?
    end

    def run_tests
      TestRunner.new(@test_binary_file_name, @compilation_stopwatch).run
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
      "/tmp/asautotest/#{get_timestamp}.swf"
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
