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
