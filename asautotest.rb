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

  def initialize(source_directory, test_file)
    @source_directory = source_directory
    @test_file = test_file

    @flashplayer = "/Applications/Flash Player.app/Contents/MacOS/Flash Player"
    @mxmlc = "/Users/daniel/Downloads/flex-4-sdk/bin/mxmlc"
    
    info "Source directory: #@source_directory"
    info "Test file: #@test_file"

    start
  end

  def start
    @watcher = Watcher.new { |directories| handle_change(directories) }
    @watcher.watch_directories([@source_directory])
    start_listening
    @watcher.start
  end

  def start_listening
    info "Ready."
  end

  def handle_change(directories)
    compile
    start_listening
  end

  def compile
    @binary_name = "/tmp/asautotest/#{get_timestamp}.swf"
    begin_info "Change detected; compiling"
    output = IO.popen("#{compile_command} 2>&1") { |x| x.readlines }
    if $? == 0
      end_info "ok"
      test
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
    info "Running tests."
    
    Open4.popen4(test_command) do |pid, stdin, stdout, stderr|
      begin
        Timeout.timeout(3) do
          catch(:done) do
            loop do
              line = stderr.readline
              case line
              when "done"
                info "Test run finished."
                throw :done
              else
                puts ">> #{line}"
              end
            end
          end
        end
      rescue Timeout::Error
        info "Test run taking too long; aborting."
      end

      if Open4.alive? pid
        begin_info "Killing test process"
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

