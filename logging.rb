module ASAutotest
  module Logging
    def self.verbose= value
      @verbose = value
    end

    def self.verbose?
      @verbose == true
    end

    def verbose?
      Logging.verbose?
    end

    def info(message)
      puts info_string(message)
    end

    def verbose_info(message)
      info(message) if verbose?
    end

    def info_string(message)
      "asautotest: #{message}"
    end
  
    def begin_info(message)
      STDOUT.print info_string("#{message}...")
      STDOUT.flush
    end
  
    def end_info(message)
      puts " #{message}."
    end
  
    def print_divider
      info("-" * 60)
    end

    def verbose_begin_info(message)
      begin_info(message) if verbose?
    end

    def verbose_end_info(message)
      end_info(message) if verbose?
    end

    def quiet_info(message)
      info(message) if not verbose?
    end
  end
end
