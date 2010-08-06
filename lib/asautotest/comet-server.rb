# -*- coding: utf-8 -*-
# comet-server.rb --- simple HTTP server for use with comet clients
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

require "socket"

module ASAutotest
  class CometServer
    def initialize(port, pipe)
      @server = TCPServer.new(port)
      @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      @mutex = Mutex.new
      @variable = ConditionVariable.new
      @pipe = pipe
    end
  
    def run
      Thread.new { loop { accept } }
      @pipe.each_line { @variable.broadcast }
    end

    def accept
      Handler.new(@mutex, @variable, @server.accept).start
    end

    class Handler
      def initialize(mutex, variable, socket)
        @mutex = mutex
        @variable = variable
        @socket = socket
      end
  
      def start
        Thread.new { run }
      end
  
      def run
        @mutex.synchronize { @variable.wait(@mutex) }
        @socket.puts "HTTP/1.0 204"
        @socket.close
      end
    end
  end
end
