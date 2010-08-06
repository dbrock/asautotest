# -*- coding: utf-8 -*-
# utilities.rb --- various handy utilities and monkey patches
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

module Kernel
  def returning(value)
    yield value ; value
  end

  def gather(&block)
    returning([], &block)
  end

  def build_string(&block)
    returning("", &block)
  end

  def ljust(string, width)
    string + padding(string, width)
  end

  def rjust(string, width)
    padding(string, width) + string
  end

  def padding(string, width)
    " " * [0, width - string_width(string)].max
  end

  def string_width(string)
    string.gsub(/\e.*?m/, "").size
  end
end

class String
  def trim
    gsub(/^\s+|\s$/, "")
  end
end

module Enumerable
  def sum
    result = 0
    each { |x| result += x }
    result
  end
end
