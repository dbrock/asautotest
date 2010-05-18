module ASAutotest
  class CompilationRunner  
    include Logging

    def initialize(options)
      @source_directories = options[:source_directories]
      @input_file_name = options[:input_file_name]
      @output_file_name = options[:output_file_name]
    end

    def successful?
      @success == true
    end

    def run
      begin_info("Compiling")
      output = IO.popen("#{compile_command} 2>&1") { |x| x.readlines }
      if $? == 0
        end_info "ok"
        @success = true
      else
        end_info "failed"
        @success = false
        until output.empty?
          line = output.shift
          case line
          when /^Loading configuration file /
          when /^(.*?)\((\d+)\).*?col:\s+(\d+)\s+(.*)/
            file_name = strip_file_name($1)
            line_number = $2
            column_number = $3
            message = $4.sub(/^Error:\s+/, "")
            location = "#{file_name} (line #{line_number})"
  
            source_lines = []
  
            while !output.empty? and output.first =~ /^\s/
              source_lines << output.shift
            end
  
            puts
            puts "!! #{location}"
            puts "!! #{message}"
            
            for line in source_lines do
              puts "|| #{line}" if line =~ /\S/
            end
  
            puts
          else
            puts ">> #{line}"
          end
        end
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

    def build_string
      result = ""
      yield(result)
      result
    end
  end
end
