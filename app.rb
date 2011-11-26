require 'fiber'
require 'pp'
require 'json'

Thread.abort_on_exception = true
$response = ""
$paused_fibers = {}
$num_calls = 0

class EMTestSubHandler
  attr_reader :received

  def on_readable(socket, messages)
    $num_calls = $num_calls + 1
    pp $paused_fibers.keys
    puts "# of messages: #{messages.size}"

    messages.each do |m|
      message = m.copy_out_string
      payload = JSON.parse(message)
      data = payload['data']
      request_id = payload['request_id']

      puts "message received, request id:#{request_id}, #{data}"
      if $paused_fibers[request_id.to_s]
        $paused_fibers.delete(request_id.to_s).resume data
      else
        puts "tried to resume a fiber that doesnt exist: #{request_id.to_s}"
      end
    end

  end
end

class App < Sinatra::Base
  register Sinatra::Synchrony
  get '/' do
    puts "request received: #{request.object_id}"
    ctx = EM::ZeroMQ::Context.new(1)

    sub_socket = ctx.connect(ZMQ::SUB, 'tcp://127.0.0.1:5556', EMTestSubHandler.new)
    sub_socket.subscribe()

    push_socket = ctx.connect(ZMQ::PUSH, "tcp://127.0.0.1:5555")

    message = {
      :data => "Hello World #{Time.now}",
      :request_id => request.object_id
    }
    push_socket.send_msg(message.to_json)

    $paused_fibers[request.object_id.to_s] = Fiber.current
    puts "before yield, request id: #{request.object_id}"
    message = Fiber.yield
    puts "after yield, request id: #{request.object_id}"

    sub_socket.unbind
    push_socket.unbind

    puts "done, request id: #{request.object_id}, num_calls: #{$num_calls}"
    message
  end
end
