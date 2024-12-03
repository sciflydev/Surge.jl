module Surge

using StateSignals  
using JSON
using HTTP  

export start_websocket_server, attach_websocket, start_server, stop_server
export Signal, effect, @signal, computed, infalidate, pull!

const signal_map = Dict{Symbol, StateSignals.Signal}()

const client_sockets = Set{HTTP.WebSockets.WebSocket}()

function attach_websocket(signal::Signal)
    signal_map[signal.id] = signal
    
    effect(() -> begin
        val = signal()
        msg = JSON.json(Dict("type" => "update", "id" => string(signal.id), "value" => val))
        for ws in client_sockets
            WebSockets.send(ws, msg)
        end
    end)
    
    return signal
end

"""
    start_websocket_server(port)

Starts the WebSocket server using HTTP.jl on the specified port.
"""
function start_websocket_server(port)
    println("Starting WebSocket server on port $port...")
    server = @async HTTP.WebSockets.listen("127.0.0.1", port) do ws
        push!(client_sockets, ws)
        try
            # Send initial state of all signals to the new client
            for (id, signal) in signal_map
                msg = JSON.json(Dict("type" => "update", "id" => string(id), "value" => signal()))
                WebSockets.send(ws, msg)
            end
            
            for msg in ws  
                handle_message(ws, msg)  
            end
        finally
            delete!(client_sockets, ws)
            close(ws)
        end
    end
    return server
end

function handle_message(ws::HTTP.WebSockets.WebSocket, msg)
    data = JSON.parse(msg)  
    if data["type"] == "update"
        id = Symbol(data["id"])
        val = data["value"]
        if haskey(signal_map, id)
            signal = signal_map[id]
            signal(val)  
        end
    end
end

function start_server(port=8080)
    http_server = @async HTTP.serve(port) do request::HTTP.Request
        if request.target == "/"
            return HTTP.Response(200, read(joinpath("index.html")))
        else
            return HTTP.Response(404)
        end
    end

    ws_server = start_websocket_server(port+1)
    return (http= http_server, websocket= ws_server)
end

"""
    stop_server(servers)

Stops both the HTTP and WebSocket servers and cleans up connections.
Takes the tuple returned by start_server().
"""
function stop_server(servers)
    # Close all websocket connections
    for ws in client_sockets
        close(ws)
    end
    empty!(client_sockets)
    
    # Stop both servers
    Base.schedule(servers.http, InterruptException(); error=true)
    Base.schedule(servers.websocket, InterruptException(); error=true)
    
    # Clear signal map
    empty!(signal_map)
end

end 

