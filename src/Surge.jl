module Surge

using StateSignals  
using JSON
using HTTP  

export start_websocket_server, attach_websocket, start_server, stop_server, expose_signal
export Signal, effect, @signal, computed, infalidate, pull!

const signal_map = Dict{Symbol, StateSignals.Signal}()

const connected_clients = Set{HTTP.WebSockets.WebSocket}()

function expose_signal(signal::Signal)
    signal_map[signal.id] = signal
    return signal
end

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
    start_websocket_server(port)

Starts the WebSocket server using HTTP.jl on the specified port.
"""
function start_websocket_server(port)
    println("Starting WebSocket server on port $port...")
    server = HTTP.WebSockets.listen("127.0.0.1", port) do ws
        push!(connected_clients, ws)
        client_signal_map = deepcopy(signal_map)
        attach_websocket(collect(values(client_signal_map)), ws)
        try
            # Send initial state of all signals to the new client
            for (_, signal) in client_signal_map
                msg = JSON.json(Dict("type" => "update", "id" => string(signal.id), "value" => signal()))
                WebSockets.send(ws, msg)
            end
            
            for msg in ws
                handle_message(ws, msg, client_signal_map)  
            end
        finally
            delete!(connected_clients, ws)
            close(ws)
        end
    end
    return server
end

function handle_message(ws::HTTP.WebSockets.WebSocket, msg, client_signal_map)
    data = JSON.parse(msg)  
    if data["type"] == "update"
        id = Symbol(data["id"])
        val = data["value"]
        if haskey(signal_map, id)
           client_signal_map[id](val)
        end
        msg = JSON.json(Dict("type" => "ACK"))
        WebSockets.send(ws, msg)
    end
end

function start_server(port=8080)
    ws_server = start_websocket_server(port)
    return ws_server
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

