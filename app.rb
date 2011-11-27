require 'fiber'
require 'pp'
require 'json'

Thread.abort_on_exception = true
# $response = ""
# $paused_fibers = {}
# $num_calls = 0
# 
# class EMTestSubHandler
#   attr_reader :received
# 
#   def on_readable(socket, messages)
#     $num_calls = $num_calls + 1
#     pp $paused_fibers.keys
#     puts "# of messages: #{messages.size}"
# 
#     messages.each do |m|
#       message = m.copy_out_string
#       payload = JSON.parse(message)
#       data = payload['data']
#       request_id = payload['request_id']
# 
#       puts "message received, request id:#{request_id}, #{data}"
#       if $paused_fibers[request_id.to_s]
#         $paused_fibers.delete(request_id.to_s).resume data
#       else
#         puts "tried to resume a fiber that doesnt exist: #{request_id.to_s}"
#       end
#     end
# 
#   end
# end


module EventMachine
  module EngineJS
    class Handler
      attr_reader :received
      
      def on_readable(socket, messages)
        puts "Callback Fiber: #{Fiber.current.object_id}"
        messages.each do |m|
          message = JSON.parse(m.copy_out_string)
          uuid = message['uuid']
          data = message['message']
          if Client.halted_fibers[uuid]
            puts "halted fibers remaining: #{Client.halted_fibers.size}"
            Client.halted_fibers.delete(uuid).resume data
          else
            puts "looking for missing fiber"
            #pp Client.halted_fibers
            #Fiber.yield
          end
        end
      end
    end

    class Client
      class << self
        attr_accessor :halted_fibers
      end
      @halted_fibers = {}
      
      def initialize(uuid, ctx)
        @uuid = uuid
        self.class.halted_fibers[@uuid] = Fiber.current

        @push_socket = ctx.connect(ZMQ::PUSH, "tcp://127.0.0.1:5555")
        @sub_socket = ctx.connect(ZMQ::SUB, 'tcp://127.0.0.1:5556', Handler.new)
        @sub_socket.subscribe()

      end

      def run(message)
        data = {
          :uuid => @uuid,
          :message => message
        }
        @push_socket.send_msg(data.to_json)
        puts "message sent"
        response = Fiber.yield
        puts "after yield"
        yield response
      end

      def close
        @sub_socket.unbind
        @push_socket.unbind
      end

    end
  end
end


class App < Sinatra::Base
  register Sinatra::Synchrony
  
  puts "Root Fiber: #{Fiber.current.object_id}"
  ctx = EM::ZeroMQ::Context.new(1)

  get '/' do
    puts "Request Fiber: #{Fiber.current.object_id}, Request ID: #{request.object_id.to_s}"
    message = nil
    client = EventMachine::EngineJS::Client.new(request.object_id.to_s, ctx)    
    client.run("Hello World #{Time.now}") do |eval|
      puts "Done"
      message = eval
    end

    client.close

    message
  end
end
