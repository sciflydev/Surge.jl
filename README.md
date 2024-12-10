# Surge.jl

[![Test workflow status](https://github.com/sciflydev/Surge.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/sciflydev/Surge.jl/actions/workflows/Test.yml?query=branch%3Amain)

A package that exposes reactive state via WebSockets, enabling real-time synchronization between Julia backends and web clients. It uses [StateSignals.jl](https://github.com/sciflydev/StateSignals.jl) for managing reactive states, and exposes their values via websockets.

You can find [here](https://github.com/sciflydev/IrisSurge) a demo application with a `Surge.jl` backend and a VueJS frontend. See it live [here](https://iris.carryall.app/) with a VueJS frontend.

## Example

Define some signals and start the server:

```julia
using Surge: Signal, computed, effect, start_server

counter = Signal(0,:counter)
countertwo = Signal(6,:countertwo)
total = computed(() -> counter() + countertwo(), :total)
word = Signal("hello", :word)


effect(() -> println("Counter updated to ", counter()))
effect(() -> println("Countertwo updated to ", countertwo()))
effect(() -> println("Total is ", total()))


server = start_server([counter, countertwo, total, word], 8080)
```

You can now send websocket messages as

```julia
using HTTP.WebSockets
using JSON

WebSockets.open("ws://localhost:8080'") do ws
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

You'll see in the REPL that the effects are triggered and the total is updated.
