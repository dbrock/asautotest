require "rubygems"
require "fssm"
require "logging"
require "compilation-runner"
require "test-runner"

module ASAutotest
  class Main
    include Logging

    WATCH_GLOB = "**/[^.]*.{as,mxml}"

    def initialize(source_directory, test_source_file_name)
      @source_directory = source_directory
      @test_source_file_name = test_source_file_name
    end

    def self.run(*arguments)
      new(*arguments).run
    end

    def run
      print_header
      build
      monitor_changes
    end

    def print_header
      print_divider
      info "Source directory: #@source_directory"
      info "Test root file: #@test_source_file_name"
      print_divider
    end
  
    def monitor_changes
      on_before_wait
      FSSM.monitor(@source_directory, WATCH_GLOB) do |path|
        path.update do |base, relative|
          on_after_wait
          handle_change
          on_before_wait
        end
      end
    end

    def on_before_wait
      print_divider
      begin_info "Waiting for changes"
    end

    def on_after_wait
      end_info "ok"
    end
  
    def handle_change
      build
    end

    def build
      compile
      if compilation_successful?
        run_tests
        delete_test_binary
      end
    end

    def compile
      @test_binary_file_name = get_test_binary_file_name
      @compilation = CompilationRunner.new \
        :source_directory => @source_directory,
        :input_file_name => @test_source_file_name,
        :output_file_name => @test_binary_file_name
      @compilation.run
    end

    def compilation_successful?
      @compilation.successful?
    end

    def run_tests
      TestRunner.new(@test_binary_file_name).run
    end

    def delete_test_binary
      begin_info("Deleting binary")
      begin
        File.delete(@test_binary_file_name)
        end_info("ok")
      rescue Exception => exception
        end_info("failed: #{exception.message}")
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

ASAutotest::Main.run \
  File.dirname(__FILE__) + "/test-project/src",
  File.dirname(__FILE__) + "/test-project/src/specification.as"
