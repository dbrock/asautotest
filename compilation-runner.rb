module ASAutotest
  class CompilationRunner  
    include Logging

    MXMLC = "/Users/daniel/Downloads/flex-4-sdk/bin/mxmlc"

    def initialize(options)
      @source_directory = options[:source_directory]
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
          when /#{@source_directory}\/(.*?)\((\d+)\).*?col:\s+(\d+)\s+(.*)/
            file_name = $1
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
  
    def compile_command
      %{"#{MXMLC}" -compiler.source-path "#@source_directory"} +
        %{ -output "#@output_file_name" "#@input_file_name"}
    end
  end
end
