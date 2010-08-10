# -*- coding: utf-8 -*-
# logging.rb --- mixins for logging and various other utilities
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
      say "\e[1;31m!!\e[0m #{message}"
    end

    def hint(message)
      say "\e[34m#{message}\e[0m"
    end

    def whisper(*arguments, &block)
      if block_given?
        whisper_with_block(*arguments, &block)
      else
        whisper_without_block(*arguments)
      end
    end

    def barf(message)
      puts "\e[1;31m??\e[0m #{message}"
    end

    # ------------------------------------------------------

    def say_without_block(message)
      puts "#{PREFIX}#{message}"
    end

    def say_with_block(message, ok_message = "ok", error_message = "failed")
      start_saying(message)
      status = ""
      yield(status)
      end_saying(status.empty? ? ok_message : status)
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
