require "rubygems"
require "sinatra"

get "/" do
  sleep 5
  "hello"
end
