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
