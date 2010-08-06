# -*- coding: utf-8 -*-
# stopwatch.rb --- utility class for measuring delays
# Copyright (C) 2010  Go Interactive

# This file is part of asautotest.

# asautotest is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# asautotest is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with asautotest.  If not, see <http://www.gnu.org/licenses/>.

module ASAutotest
  class Stopwatch
    def initialize
      @start_time = current_time
    end

    def to_s(decimals = 3)
      round(n_elapsed_seconds, decimals).to_s
    end

    def stop
      @end_time = current_time
    end

    def end_time
      @end_time || current_time
    end

    def current_time
      Time.new
    end

    def n_elapsed_seconds
      end_time - @start_time
    end

    def round(number, n_decimals)
      (number * 10 ** n_decimals).round.to_f / 10 ** n_decimals
    end
  end
end
