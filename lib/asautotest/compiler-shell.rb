module ASAutotest
  class CompilerShell
    include Logging

    attr_reader :output_file_name
    attr_reader :source_directories

    def initialize(options)
      @source_directories = options[:source_directories]
      @library_path = options[:library_path]
      @input_file_name = options[:input_file_name]
      @output_file_name = options[:output_file_name]
    end

    def start
      say "Starting compiler shell" do
        @process = IO.popen("#{FCSH} 2>&1", "r+")
        read_until_prompt
      end
    end

    PROMPT = "\n(fcsh) "

    def read_until_prompt
      build_string do |result|
        result << @process.readpartial(100) until result.include? PROMPT
      end.lines.entries[0 .. -2]
    end

    def run_compilation
      if @compilation_initialized
        run_saved_compilation
      else
        run_first_compilation
      end
    end

    def run_first_compilation
      @process.puts(compile_command)
      @compilation_initialized = true
      read_until_prompt
    end

    def run_saved_compilation
      @process.puts("compile 1")
      read_until_prompt
    end

    def compile_command
      build_string do |result|
        result << %{mxmlc}
        for source_directory in @source_directories do
          result << %{ -compiler.source-path=#{source_directory}}
        end
        for library in @library_path do
          result << %{ -compiler.library-path=#{library}}
        end
        result << %{ -output=#@output_file_name}
        result << %{ -static-link-runtime-shared-libraries}
        result << %{ #@input_file_name}
      end
    end
  end
end
