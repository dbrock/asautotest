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

        @problems.each &:print_report
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

      def self.parse(input)
        case input
        when /^(.*):(.*)$/
          Type[$1, $2]
        else
          Type[nil, input]
        end
      end

      def to_s ; name end

      def full_name
        "#{package}.#{name}"
      end

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
      
      def source_line
        build_string do |result|
          result << location.source_line.trim
          result << " ..." unless location.source_line =~ /[;{}]\s*$/
        end
      end

      def line_number
        location.line_number
      end

      def column_number
        location.column_number - indentation_width
      end

      def indentation_width
        location.source_line =~ /^(\s*)/ ; $1.size
      end

      def self.[] message, location
        returning parse(message) do |problem|
          problem.location = location
        end
      end

      def self.parse(message)
        case message.sub(/^(Error|Warning):\s+/, "")
        when /^Definition (\S+) could not be found.$/i
          UndefinedImport.new(Type.parse($1))
        when /^Call to a possibly undefined method (\S+) .* type (\S+).$/i
          UndefinedMethod.new(Member[Type.parse($2), $1])
        when /^Call to a possibly undefined method (\S+).$/i
          UndefinedMethod.new(Member[nil, $1])
        when /^Access of undefined property (\S+).$/i
          UndefinedProperty.new(Member[nil, $1])
        when /^Type was not found or was not a compile-time constant: (\S+).$/i
          UndefinedType.new(Type.parse($1))
        when /^Illegal assignment to a variable specified as constant.$/i
          ConstantAssignment.new
        when /^return value for function '(\S+)' has no type declaration.$/i
          MissingReturnType.new(Member[nil, $1])
        when /^Interface (\S+) was not found.$/i
          InterfaceNotFound.new(Type.parse($1))
        when /^Implicit coercion of a value of type (\S+) to an unrelated type (\S+).$/i
          TypeMismatch.new(Type.parse($2), Type.parse($1))
        when /^Interface method ((?:get |set )?\S+) in namespace (\S+) not implemented by class (\S+).$/i
          MissingImplementation.new(Member[Type.parse($2), $1], Type.parse($3))
        else
          Unknown.new(message)
        end
      end

      class ConstantAssignment < Problem
        def message ; "Attempt to modify constant:" end
        def details ; identifier_source_line_details end
      end

      class UndefinedImport < Problem
        def initialize(type) @type = type end
        def message ; "Import not found:" end
        def details
          bullet_details(@type.full_name)
        end
      end

      class UndefinedMethod < Problem
        def initialize(member) @member = member end
        def message ; "Undefined method:" end
        def details ; identifier_source_line_details end
      end

      class UndefinedProperty < Problem
        def initialize(member) @member = member end
        def message ; "Undefined property:" end
        def details ; identifier_source_line_details end
      end

      class UndefinedType < Problem
        def initialize(type) @type = type end
        def message ; "Undefined type:" end
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

      class TypeMismatch < Problem
        def initialize(expected_type, actual_type)
          @expected_type = expected_type
          @actual_type = actual_type
        end

        def message ; "Expected #@expected_type but was #@actual_type:" end
        def details
          identifier_source_line_details
        end
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
          "\e[0m  * \e[1m#{@member.name}\e[0m (#{@member.type})\e[0m"
        end
      end

      class Unknown < Problem
        def initialize(message) @message = message end
        def message ; @message end
        def details ; source_line_details end
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
        "\e[0m  ... #{source_line}\e[0m"
      end

      def identifier_source_line_details
        source_line =~ /^(.{#{column_number}})([\w$]+)(.*)$/
        "\e[0m  ... #$1\e[1;4m#$2\e[0m#$3\e[0m"
      end

      def member_details
        bullet_details(@member)
      end

      def bullet_details(content)
        "\e[0m  * #{content}\e[0m"
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
