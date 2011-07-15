require 'rubygems'
require 'eventmachine'
puts "boot ok"

class Echo < EventMachine::Connection
  # include EM::Protocols::LineText2
  def initialize()
    require 'config/environment'
  end

  def receive_data(data)
    #puts "in: #{data.inspect}"
    data.split("\n").each {|d|
      #puts "line: #{d.inspect}"
      if d =~ /^[a-zA-Z_\{\[\`\d]/
        if d =~ /^_$/
          close_connection()
          return
        end
        e = begin
              e = eval(d)
            rescue Exception
              puts "Ups - " + $!
              send_data "error\n"
              return
            end
        #puts "Eval Out: #{e}"
        send_data "#{e}\n"
      end
      close_connection true
    }
  end
end

EventMachine.run {
  EventMachine.start_server '0.0.0.0', 1234, Echo
}
