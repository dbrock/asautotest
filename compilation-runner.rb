# -*- coding: utf-8 -*-
module ASAutotest
  class CompilationRunner
    class CompilationFailure < Exception ; end

    include Logging

    def initialize(options)
      @source_directories = options[:source_directories]
      @input_file_name = options[:input_file_name]
      @output_file_name = options[:output_file_name]
      @problematic_files = {}
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
      parse_output
      print_report
    end

    def print_report
      for name, file in @problematic_files do
        file.print_report
      end

      puts
    end

    def parse_output
      while has_more_lines?
        case line = read_line
        when /^Loading configuration file /
        when /^(.*?)\((\d+)\).*?col:\s+(\d+)\s+(.*)/
          file_name = $1
          line_number = $2.to_i
          column_number = $3.to_i - 1
          message = $4
          # Read four lines and pick out the second.
          source_line = read_lines(4)[1]

          location = Location[line_number, column_number, source_line]
          problem = Problem[message, location]

          add_problem(file_name, problem)
        else
          puts "?? #{line}"
        end
      end
    end

    def add_problem(file_name, problem)
      get_problematic_file(file_name) << problem
    end

    def get_problematic_file(file_name)
      if @problematic_files.include? file_name
        @problematic_files[file_name]
      else
        @problematic_files[file_name] =
          ProblematicFile.new(file_name, @source_directories)
      end
    end

    MESSAGE_COLUMN_WIDTH = 56
    LINE_NUMBER_COLUMN_WIDTH = 4

    class ProblematicFile
      def initialize(file_name, source_directories)
        @file_name = file_name
        @source_directories = source_directories
        @problems = []
      end

      def << problem
        @problems << problem
        problem.file = self
        @problems = @problems.sort_by { |x| x.location.sort_key }
      end

      def type
        Type[dirname.gsub(/\/|\\/, "."), basename.sub(/\..*$/, "")]
      end

      def problem_before(next_problem)
        returning nil do
          previous_problem = nil
          for problem in @problems do
            if problem == next_problem
              return previous_problem
            else
              previous_problem = problem
            end
          end
        end
      end

      def print_report
        puts
        print ljust("\e[1m#{basename}\e[0m", 40)
        puts "  (in #{dirname})"

        for problem in @problems do
          problem.print_report()
        end
      end

      def basename
        File.basename(@file_name)
      end

      def dirname
        File.dirname(stripped_file_name)
      end

      def stripped_file_name
        if source_directory
          @file_name[source_directory.size .. -1]
        else
          @file_name
        end
      end

      def source_directory
        @source_directories.find do |directory|
          @file_name.start_with? directory
        end
      end
    end

    class Location
      extend Bracketable
      attr_reader :line_number, :column_number, :source_line
      def initialize(line_number, column_number, source_line)
        @line_number = line_number
        @column_number = column_number
        @source_line = source_line
      end

      def sort_key
        [line_number, column_number]
      end
    end

    class Type
      extend Bracketable
      attr_reader :package, :name
      def initialize(package, name)
        @package = package
        @name = name
      end

      def to_s ; name end

      def == other
        package == other.package and name == other.name
      end
    end

    class Member
      extend Bracketable
      attr_reader :type, :name
      def initialize(type, name)
        @type = type
        @name = name
      end

      def to_s
        @type ? "#{@type.name}.#@name" : "#@name"
      end
    end

    class Problem
      attr_accessor :location
      attr_accessor :file

      def details ; nil end
      def source_line ; location.source_line end
      def line_number ; location.line_number end

      def column_number
        location.column_number - indentation_width
      end

      def indentation_width
        source_line =~ /^(\s*)/ ; $1.size
      end

      def self.[] message, location
        returning parse(message) do |problem|
          problem.location = location
        end
      end

      def self.parse(message)
        case message.sub(/^(Error|Warning):\s+/, "")
        when /^Interface method ((?:get |set )?\S+) in namespace (\S+):(\S+) not implemented by class (\S+):(\S+).$/i
          MissingImplementation.new(Member[Type[$2, $3], $1], Type[$4, $5])
        when /^Call .* undefined method (\S+) .* type (\S+):(\S+).$/i
          UndefinedMethod.new(Member[Type[$2, $3], $1])
        when /^return value for function '(\S+)' has no type declaration.$/i
          MissingReturnType.new(Member[nil, $1])
        when /^Interface (\S+) was not found.$/i
          InterfaceNotFound.new(Type[nil, $1])
        else
          Unknown.new(message)
        end
      end

      def print_report
        unless message == last_message
          print message_column
          print dummy_line_number_column unless message_column_overflowed?
          puts
        end

        if details
          print details_column
          print line_number_column
          puts
        end
      end

      def message_column_overflowed?
        message_column.size > MESSAGE_COLUMN_WIDTH
      end

      def message_column
        ljust("  #{message}", MESSAGE_COLUMN_WIDTH)
      end

      def details_column
        ljust("  #{details}  ", MESSAGE_COLUMN_WIDTH)
      end

      def line_number_column
        rjust("\e[1m#{line_number}\e[0m", LINE_NUMBER_COLUMN_WIDTH)
      end

      def dummy_line_number_column
        rjust("\e[0m|\e[0m", LINE_NUMBER_COLUMN_WIDTH)
      end

      def last_message
        previous.message if previous
      end

      def previous
        file.problem_before(self)
      end

      def source_line_details
        "\e[34m#{raw_source_line_details}\e[0m"
      end

      def raw_source_line_details
        build_string do |result|
          result << source_line.trim
          result << " ..." unless source_line =~ /[;{}]\s*$/
        end
      end

      def identifier_source_line_details
        raw_source_line_details =~
          /^(.{#{column_number}})([\w$]+)(.*)$/
        "\e[34m  ... #$1\e[1m#$2\e[0;34m#$3\e[0m"
      end

      def member_details
        "\e[34m  * #@member\e[0m"
      end

      class MissingImplementation < Problem
        def initialize(member, implementing_type)
          @member = member
          @implementing_type = implementing_type
        end

        def message
          if file.type == @implementing_type
            "Missing implementation:"
          else
            "Missing implementation in #@implementing_type:"
          end
        end

        def details
          "\e[34m  * \e[1m#{@member.name}\e[0;34m (#{@member.type})\e[0m"
        end
      end

      class UndefinedMethod < Problem
        def initialize(member) @member = member end
        def message ; "Undefined method:" end
        def details ; identifier_source_line_details end
      end

      class MissingReturnType < Problem
        def initialize(member) @member = member end
        def message ; "Missing return type:"  end
        def details ; member_details end
      end

      class InterfaceNotFound < Problem
        def initialize(member) @member = member end
        def message ; "Interface not found:"  end
        def details ; member_details end
      end

      class Unknown < Problem
        def initialize(message) @message = message end
        def message ; @message end
        def details ; source_line_details end
      end
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

    # ------------------------------------------------------

    def has_more_lines?
      not @output.empty?
    end

    def read_lines(n)
      @output.shift(n)
    end

    def read_line
      @output.shift
    end
  end
end
