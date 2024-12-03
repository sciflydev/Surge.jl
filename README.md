# Surge.jl

A package that exposes reactive state via WebSockets, enabling real-time synchronization between Julia backends and web clients. It uses [StateSignals.jl](https://github.com/sciflydev/StateSignals.jl) for managing reactive states, and exposes their values via websockets.

## Example

Define some signals and start the server:

```julia
using Surge: Signal, computed, effect

counter = Signal(0,:counter)
countertwo = Signal(6,:countertwo)
total = computed(() -> counter() + countertwo(), :total)
word = Signal("hello", :word)


effect(() -> println("Counter updated to ", counter()))
effect(() -> println("Countertwo updated to ", countertwo()))
effect(() -> println("Total is ", total()))

map(attach_websocket, [counter, countertwo, total, word])
server=start_server(8080)
```

Open the file `index.html` in the `example` folder. You'll see the signal values and controls to modify them.

Alternatively, you can send websocket messages as

```julia
using HTTP.WebSockets
using JSON

WebSockets.open("ws://localhost:8081") do ws
    # Send an update message
    update_msg = JSON.json(Dict(
        "type" => "update",
        "id" => "counter",  # matches the signal ID
        "value" => 42
    ))
    WebSockets.send(ws, update_msg)

    response = String(WebSockets.receive(ws))
    println("Received: ", response)
end
```
