module ASAutotest
  class CompilationRunner
    class CompilationFailure < Exception ; end

    include Logging

    def initialize(options)
      @source_directories = options[:source_directories]
      @input_file_name = options[:input_file_name]
      @output_file_name = options[:output_file_name]
    end

    def successful?
      @success == true
    end

    def run_compilation
      @output = IO.popen("#{compile_command} 2>&1") { |x| x.readlines }
      @success = $? == 0
      raise CompilationFailure if not successful?
    end

    def run
      say("Compiling") { run_compilation }
    rescue CompilationFailure
      parse_failure
    end

    def parse_failure
      parse_failure_line(read_failure_line) until @output.empty?
    end

    def read_failure_line
      @output.shift
    end

    def parse_failure_line(line)
      case line
      when /^Loading configuration file /
      when /^(.*?)\((\d+)\).*?col:\s+(\d+)\s+(.*)/
        parse_error \
          :file_name => $1,
          :line_number => $2,
          :column_number => $3,
          :message => $4
      else
        puts ">> #{line}"
      end
    end

    def parse_error(options)
      file_name = strip_file_name(options[:file_name])
      line_number = options[:line_number]
      column_number = options[:column_number]
      message = options[:message].sub(/^Error:\s+/, "")

      location = "#{file_name} (line #{line_number})"
      source_lines = read_indented_lines.grep(/\S/)

      puts
      puts "!! #{location}"
      puts "!! #{message}"

      for line in source_lines
        puts "|| #{line}"
      end

      puts
    end

    def read_indented_lines
      read_lines_matching(/^\s/)
    end

    def read_lines_matching(pattern)
      gather do |result|
        with_lines_matching(pattern) { |line| result << line }
      end
    end

    def with_lines_matching(pattern)
      while !@output.empty? and @output.first =~ pattern
        yield @output.shift
      end
    end

    def strip_file_name(file_name)
      for source_directory in @source_directories do
        if file_name.start_with? source_directory
          file_name[source_directory.size .. -1]
        end
      end

      file_name
    end
  
    def compile_command
      build_string do |result|
        result << %{"#{MXMLC}"}      
        for source_directory in @source_directories do
          result << %{ -compiler.source-path "#{source_directory}"}
        end
        result << %{ -output "#@output_file_name"}
        result << %{ "#@input_file_name"}
      end
    end
  end
end
