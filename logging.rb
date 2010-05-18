module ASAutotest
  module Logging
    def info(message)
      puts info_string(message)
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
  end
end
