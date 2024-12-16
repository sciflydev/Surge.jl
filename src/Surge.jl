module Surge

using StateSignals  
using JSON
using HTTP  

export start_websocket_server, attach_websocket, start_server, stop_server, expose_signal
export Signal, Resource, effect, @signal, computed, invalidate, pull!,

const signal_map = Dict{Symbol, StateSignals.Signal}()

const connected_clients = Set{HTTP.WebSockets.WebSocket}()

function attach_websocket(signal::Signal, ws::HTTP.WebSockets.WebSocket)
    
    effect(() -> begin
        val = signal()
        msg = JSON.json(Dict("type" => "update", "id" => string(signal.id), "value" => val))
        WebSockets.send(ws, msg)
    end)
    
    return signal
end

function attach_websocket(signals::Vector{Signal}, ws::HTTP.WebSockets.WebSocket)
    map(signal -> attach_websocket(signal, ws), signals)
end

"""
    start_websocket_server(signals, port)

Starts the server that will expose the signals via websockets.
"""
function start_server(signals::Vector{<:Signal}, port::Int; async=false)
    map((s) -> signal_map[s.id] = s, signals)
    println("Starting WebSocket server on port $port...")
    server_task = @async HTTP.WebSockets.listen("127.0.0.1", port) do ws
        push!(connected_clients, ws)
        client_signal_map = deepcopy(signal_map)
        # this function attaches a websocket and triggers first sync
        attach_websocket(collect(values(client_signal_map)), ws)
        try
            for msg in ws
                handle_message(ws, msg, client_signal_map)  
            end
        finally
            delete!(connected_clients, ws)
            close(ws)
        end
    end
    !async && return wait(server_task)
    return server_task
end

function handle_message(ws::HTTP.WebSockets.WebSocket, msg, client_signal_map)
  data = JSON.parse(msg)  
  if data["type"] == "update"
    msg = JSON.json(Dict("type" => "ACK"))
    WebSockets.send(ws, msg)
    id = Symbol(data["id"])
    val = data["value"]
    if haskey(signal_map, id)
      client_signal_map[id](val) #TODO: this shouldn't trigger the ws sync effect
    end
  elseif data["type"] == "get"
    id = Symbol(data["id"])
    if haskey(signal_map, id)
      signal = client_signal_map[id]
      msg = JSON.json(Dict("type" => "update", "id" => string(signal.id), "value" => signal()))
      WebSockets.send(ws, msg)
    end
  end
end


"""
    stop_server(servers)

Stops the WebSocket server and cleans up connections.
"""
function stop_server(server)
    # Close all websocket connections
    for ws in connected_clients
        close(ws)
    end
    empty!(connected_clients)
    
    # Stop server
    Base.schedule(server, InterruptException(); error=true)
    
    # Clear signal map
    empty!(signal_map)
end

end 

