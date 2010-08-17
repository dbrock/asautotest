# -*- coding: utf-8 -*-
# compilation-result.rb --- collect the results of a compilation
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
  class CompilationResult
    attr_reader :n_recompiled_files
    attr_reader :problematic_files
    attr_reader :unrecognized_lines
    attr_reader :summaries

    def initialize
      @problematic_files = {}
      @n_recompiled_files = nil
      @unrecognized_lines = []
      @summaries = []
    end
    
    # ----------------------------------------------------

    def source_directories= value
      @source_directories = value
    end

    def add_problem(file_name, problem)
      get_problematic_file(file_name) << problem unless
        @typing == :dynamic and problem.type_warning?
    end

    def get_problematic_file(file_name)
      if @problematic_files.include? file_name
        @problematic_files[file_name]
      else
        @problematic_files[file_name] =
          ProblematicFile.new(file_name, @source_directories)
      end
    end

    # ----------------------------------------------------

    def add_unrecognized_line(line)
      @unrecognized_lines << line
    end

    def add_summary(summary)
      @summaries << summary
    end

    # ----------------------------------------------------

    def any_type_warnings?
      @problematic_files.values.any? &:any_type_warnings?
    end

    def successful?
      @summaries.all? { |x| x[:successful?] }
    end

    def failed?
      not successful?
    end

    def bootstrap?
      @summaries.all? { |x| x[:n_recompiled_files] == nil }
    end

    def n_recompiled_files
      @summaries.inject(0) { |a, x| a + x[:n_recompiled_files] }
    end

    def recompilation?
      not bootstrap?
    end

    def did_anything?
      bootstrap? or n_recompiled_files > 0
    end
  end
end
