# -*- coding: utf-8 -*-
# compilation-output-parser.rb --- parse the output of one compilation
# Copyright (C) 2010  Go Interactive

# This file is part of ASAutotest.

# ASAutotest is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# ASAutotest is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with ASAutotest.  If not, see <http://www.gnu.org/licenses/>.

module ASAutotest
  class OutputParser
    def initialize(output, request, result)
      @output = output
      @request = request
      @result = result
    end

    def self.parse(*arguments)
      new(*arguments).run
    end

    def run
      parse_lines
      add_summary
    end

    def parse_lines
      @result.source_directories = @request.source_directories

      while has_more_lines?
        line = read_line
        puts ">> #{line}" if Logging.verbose?
        parse_line(line)
      end
    end

    def parse_line(line)
      case line
      when /^Loading configuration file /
      when /^fcsh: Assigned (\d+) as the compile target id/
        @request.compile_id = $1
      when /^Recompile: /
      when /^Reason: /
      when /^\s*$/
      when /\(\d+ bytes\)$/
        @successful = true
      when /^Nothing has changed /
        @n_recompiled_files = 0
      when /^Files changed: (\d+) Files affected: (\d+)/
        @n_recompiled_files = $1.to_i + $2.to_i
      when /^(.*?)\((\d+)\): col: (\d+) (.*)/
        file_name = $1
        line_number = $2.to_i
        column_number = $3.to_i - 1
        message = $4
        source_line = read_lines(4)[1]

        location = Location[line_number, column_number, source_line]
        problem = Problem[message, location]

        @result.add_problem(file_name, problem)
      when /^Error: (.*)/
        @result.add_problem(nil, Problem[$1, nil])
      when /^(.*?): (.*)/
        @result.add_problem($1, Problem[$2, nil])
      else
        @result.add_unrecognized_line(line)
      end
    end

    def add_summary
      @result.add_summary \
        :request => @request,
        :successful? => @successful,
        :n_recompiled_files => @n_recompiled_files
    end

    def has_more_lines?
      not @output.empty?
    end

    def read_lines(n)
      @output.shift(n).map(&:chomp)
    end

    def read_line
      @output.shift.chomp
    end
  end
end
