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
          growl_error "Compilation failed\n" +
            "#{@result.n_problems} problems " +
            "in #{@result.n_problematic_files} files"
        elsif @result.bootstrap?
          status << "recompiled everything in #{compilation_time}"
          growl "Compilation successful\n#{status.capitalize}."
        elsif @result.did_anything?
          status << "recompiled #{@result.n_recompiled_files} "
          status << "file#{@result.n_recompiled_files == 1 ? "" : "s"} "
          status << "in #{compilation_time}"
          growl "Compilation successful\n#{status.capitalize}."
        else
          status << "nothing changed"
        end
      end
    end

    def growl(message)
      if ASAutotest::growl_enabled
        Growl.notify(message, growl_options)
      end
    end

    def growl_error(message)
      if ASAutotest::growl_enabled
        Growl.notify_error(message, growl_options)
      end
    end

    def growl_options
      { :title => growl_title, :icon => "as" }
    end

    def growl_title
      @shell.compilation_requests.map do |request|
        File.basename(request.source_file_name)
      end.join(", ")
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
