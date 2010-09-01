# -*- coding: utf-8 -*-
# compilation-runner.rb --- run compilations and report the results
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

require "asautotest/logging"

module ASAutotest
  class CompilationRunner
    class CompilationFailure < Exception ; end

    include Logging

    attr_reader :result

    def initialize(shell, options)
      @shell = shell
      @typing = options[:typing]
      @result = CompilationResult.new
    end

    def run
      @stopwatch = Stopwatch.new
      compile
      @stopwatch.stop
      print_report
    end

    def compile
      say("Compiling") do |status|
        @shell.run_compilations(@result)

        if @result.failed?
          status << "failed"
        elsif @result.did_anything?
          files = if @result.bootstrap?
                    "everything"
                  else
                    n_x(@result.n_recompiled_files, "file")
                  end
          status << "recompiled #{files} in #{compilation_time}"
        else
          status << "nothing changed"
        end

        if @result.successful?
          for summary in @result.summaries
            title = File.basename(summary[:request].source_file_name)
            if summary[:successful?] and summary[:n_recompiled_files] != 0
              files = if summary[:n_recompiled_files]
                        n_x(summary[:n_recompiled_files], "file")
                      else
                        "everything"
                      end
              time = "#{summary[:compilation_time].to_s(1)}s"
              growl_success title, "Compiled #{files} in #{time}."
            end
          end
        else
          summary = @result.summaries.find { |x| not x[:successful?] }
          file_name = summary[:first_problem].file.basename
          line_number = summary[:first_problem].line_number
          message = summary[:first_problem].plain_message
          growl_error "#{file_name}, line #{line_number}", message
        end
      end
    end

    def n_x(n, x)
      "#{n} #{x}#{n == 1 ? "" : "s"}"
    end

    def growl_success(title, message)
      if ASAutotest::growl_enabled
        options = { :title => title, :icon => "as" }
        if ASAutotest::displaying_growl_error
          options[:identifier] = GROWL_ERROR_TOKEN
          ASAutotest::displaying_growl_error = false
        end
        Growl.notify(message, options)
      end
    end

    def growl_error(title, message)
      if ASAutotest::growl_enabled
        Growl.notify_error message,
          :title => title, :sticky => true,
          :identifier => GROWL_ERROR_TOKEN
        ASAutotest::displaying_growl_error = true
      end
    end

    def compilation_time
      "~#{@stopwatch.to_s(1)} seconds"
    end

    def print_report
      for line in @result.unrecognized_lines
        barf line
      end

      for name, file in @result.problematic_files
        file.print_report
      end

      puts unless @result.problematic_files.empty?

      if @typing == nil and @result.any_type_warnings?
        hint "Use --dynamic-typing to disable type declaration warnings,"
        hint "or --static-typing to disable this hint."
      end
    end
  end
end
