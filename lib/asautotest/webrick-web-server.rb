require "webrick"

include WEBrick

class SimpleServlet < HTTPServlet::AbstractServlet
  def do_GET(request, response)
    response.body = "hello"
    sleep 5
  end
end

server = HTTPServer.new(:Port => 8080)
server.mount("/", SimpleServlet)

for signal in ["INT", "TERM"] do
  trap(signal) { server.shutdown }
end

server.start
