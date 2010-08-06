# -*- coding: utf-8 -*-
# manual-web-server.rb --- simple, bare-bones web server
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

class WebServer
  def initialize
    @server = TCPServer.new(8080)
    @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
  end

  def run
    loop { handle_request(@server.accept) }
  end

  def handle_request(socket)
    Thread.new(socket) do |socket|
      Handler.new(socket).run
    end
  end

  class Handler
    def initialize(socket)
      @socket = socket
    end

    def run
      @socket.puts "HTTP/1.0 204"
      @socket.close
    end
  end
end

WebServer.new.run
