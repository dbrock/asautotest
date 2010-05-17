require "rubygems"
require "fsevent"
require "open4"

class ASAutotest
  class Watcher < FSEvent
    def initialize(&callback)
      super
      @callback = callback
    end

    def on_change(directories)
      @callback[directories]
    end
  end

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
  
  def initialize(source_directory, test_file)
    @source_directory = source_directory
    @test_file = test_file

    @flashplayer = "/Applications/Flash Player.app/Contents/MacOS/Flash Player"
    @mxmlc = "/Users/daniel/Downloads/flex-4-sdk/bin/mxmlc"
    
    print_divider
    info "Source directory: #@source_directory"
    info "Test file: #@test_file"
    print_divider

    start
  end

  def start
    @watcher = Watcher.new { |directories| handle_change(directories) }
    @watcher.watch_directories([@source_directory])
    compile("Compiling")
    start_listening
    @watcher.start
  end

  def start_listening
    print_divider
    info "Ready."
  end

  def handle_change(directories)
    compile("Change detected; compiling")
    start_listening
  end

  def compile(message)
    @binary_name = "/tmp/asautotest/#{get_timestamp}.swf"
    begin_info(message)
    output = IO.popen("#{compile_command} 2>&1") { |x| x.readlines }
    if $? == 0
      end_info "ok; running tests"
      test
      begin_info("Deleting binary")
      begin
        File.delete(@binary_name)
        end_info("ok")
      rescue Exception => exception
        end_info("failed: #{exception.message}")
      end
    else
      end_info "failed"
      until output.empty?
        line = output.shift
        case line
        when /^Loading configuration file /
        when /#{@source_directory}\/(.*?)\((\d+)\).*?col:\s+(\d+)\s+(.*)/
          file_name = $1
          line_number = $2
          column_number = $3
          message = $4.sub(/^Error:\s+/, "")
          location = "#{file_name} (line #{line_number})"

          source_lines = []

          while !output.empty? and output.first =~ /^\s/
            source_lines << output.shift
          end

          puts
          puts "!! #{location}"
          puts "!! #{message}"
          
          for line in source_lines do
            puts "|| #{line}" if line =~ /\S/
          end

          puts
        end
      end
    end
  end

  def compile_command
    %{"#@mxmlc" -compiler.source-path "#@source_directory" -output "#@binary_name" "#@test_file"}
  end

  def test
    require "socket"

    expected_greeting = "Hello, this is a test.\n"
    policy_file_request = "<policy-file-request/>\0"

    # Make sure we can accept a policy file request as a greeting.
    unless expected_greeting.size >= policy_file_request.size
      raise "Internal error: Expected greeting is too short."
    end
    
    port = 50002
    server = TCPServer.new(port)
    server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    Open4.popen4(test_command) do |pid, stdin, stdout, stderr|
      begin
        begin_info "Accepting connection"
        # It takes at least 3 seconds to get a policy file request.
        socket = Timeout.timeout(5) { server.accept }
        end_info "ok"
        begin
          Timeout.timeout(10) do
            greeting = socket.read(expected_greeting.size)
            case greeting
            when policy_file_request
              info "!! Recieved policy file request; aborting."
              info "!! Please set up a policy server on port 843."
            when expected_greeting
              info "Performed handshake."
              catch(:done) do
                loop do
                  line = socket.readline.chomp
                  case line
                  when "done"
                    info "Test run finished."
                    throw :done
                  else
                    puts ">> #{line.inspect}"
                  end
                end
              end
            else
              info "!! Unrecognized greeting: #{greeting.inspect}"
            end            
          end
        rescue Timeout::Error
          info "!! Test run taking too long; aborting."
        end
      rescue Timeout::Error
        end_info "timeout"
        info "!! Test did not connect to localhost:#{port}."
      end

      server.close

      if Open4.alive? pid
        begin_info "Killing process"
        Open4.maim(pid, :suspend => 0.5)        
        end_info(Open4.alive?(pid) ? "ok" : "failed")
      end
    end
  end

  def test_command
    %{"#@flashplayer" "#@binary_name"}
  end

  def get_timestamp
    (Time.new.to_f * 100).to_i
  end
end

ASAutotest.new \
  File.dirname(__FILE__) + "/test-project/src",
  File.dirname(__FILE__) + "/test-project/src/specification.as"
