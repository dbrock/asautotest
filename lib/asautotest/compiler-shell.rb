# -*- coding: utf-8 -*-
# compiler-shell.rb --- wrapper around the fcsh executable
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
  class CompilerShell
    PROMPT = "\n(fcsh) "

    class PromptNotFound < Exception ; end

    include Logging

    attr_reader :compilation_requests

    def initialize(options)
      @compilation_requests = options[:compilation_requests]
    end

    def start
      say "Starting compiler shell" do
        @process = IO.popen("#{FCSH} 2>&1", "r+")
        read_until_prompt
      end
    rescue PromptNotFound => error
      shout "Could not find FCSH prompt:"
      for line in error.message.lines do
        barf line.chomp
      end
      if error.message.include? "command not found"
        shout "Please make sure that fcsh is in your PATH."
        shout "Alternatively, set the ‘FCSH’ environment variable."
      end
      exit -1
    end

    def run_compilations(result)
      for request in @compilation_requests
        run_compilation(request, result)
      end
    end

    def run_compilation(request, result)
      stopwatch = Stopwatch.new
      @process.puts(request.compile_command)
      OutputParser.parse(read_until_prompt, request, stopwatch, result)
      stopwatch.stop
    end

    def read_until_prompt
      result = ""
      until result.include? PROMPT
        result << @process.readpartial(100) 
      end
      result.lines.entries[0 .. -2]
    rescue EOFError
      raise PromptNotFound, result
    end
  end
end
