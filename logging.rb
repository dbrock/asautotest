module ASAutotest
  module Bracketable
    def [] *arguments ; new(*arguments) end
  end

  module Logging
    PREFIX = "asautotest: "
  
    def self.verbose= value
      @verbose = value
    end

    def self.verbose?
      @verbose == true
    end

    def verbose?
      Logging.verbose?
    end

    # ------------------------------------------------------

    def say(*arguments, &block)
      if block_given?
        say_with_block(*arguments, &block)
      else
        say_without_block(*arguments)
      end
    end

    def shout(message)
      say "!! #{message}"
    end

    def whisper(*arguments, &block)
      if block_given?
        whisper_with_block(*arguments, &block)
      else
        whisper_without_block(*arguments)
      end
    end

    # ------------------------------------------------------

    def say_without_block(message)
      puts "#{PREFIX}#{message}"
    end

    def say_with_block(message, ok_message = "ok", error_message = "failed")
      start_saying(message)
      yield
      end_saying(ok_message)
      ended = true
    ensure
      end_saying(error_message) unless ended
    end

    def start_saying(message)
      STDOUT.print "#{PREFIX}#{message}..."
      STDOUT.flush
    end
  
    def end_saying(message)
      STDOUT.puts " #{message}."
    end

    # ------------------------------------------------------

    def whisper_without_block(message)
      say message if verbose?
    end

    def whisper_with_block(message, ok_message = "ok", error_message = "failed")
      start_whisper(message)
      yield
      end_whisper(ok_message)
      ended = true
    ensure
      end_whisper(error_message) unless ended
    end

    def start_whisper(message)
      start_saying(message) if verbose?
    end

    def end_whisper(message)
      end_saying(message) if verbose?
    end

    # ------------------------------------------------------
  
    def new_logging_section
      say("-" * 60)
    end
  end
end
