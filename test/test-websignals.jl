using Test
using Surge
using HTTP
using JSON
using StateSignals

@testset "Surge tests" begin

    @testset "WebSocket server" begin
        # Start server on test port
        test_port = 8082
        
        # Create test signal
        counter = Signal(42, :test_counter)
        
        server = start_server([counter], test_port; async=true)
        sleep(1)

        # Connect test client
        client = HTTP.WebSockets.open("ws://127.0.0.1:$test_port") do ws
            # Should receive initial state
            answer = JSON.parse(String(HTTP.WebSockets.receive(ws)))
            @test answer["type"] == "update"
            @test answer["id"] == "test_counter"
            @test answer["value"] == 42
            
            # Test sending update from client
            update_msg = JSON.json(Dict(
                "type" => "update",
                "id" => "test_counter",
                "value" => 100
            ))
            HTTP.WebSockets.send(ws, update_msg)

            println("set to 100")
            answer = JSON.parse(String(HTTP.WebSockets.receive(ws)))
            @show answer
            @test answer["type"] == "ACK"
            answer = JSON.parse(String(HTTP.WebSockets.receive(ws)))
            @show answer
            @test answer["value"] == 100

            println("get value")
            update_msg = JSON.json(Dict(
                "type" => "get",
                "id" => "test_counter",
            ))
            HTTP.WebSockets.send(ws, update_msg)
            answer = JSON.parse(String(HTTP.WebSockets.receive(ws)))
            @show answer
            @test answer["value"] == 100
            # Wait briefly for update to process
            # Verify signal was updated
            
        end
        
        # Clean up
        stop_server(server)
    end

    @testset "Server start/stop" begin
        
        # Create and attach test signal
        test_signal = Signal("test", :test)

        server = start_server([test_signal], 8083; async=true)
        sleep(1)
        
        @test server.state == :runnable
        
        stop_server(server)
        sleep(0.5)
        
        # Verify cleanup
        @test isempty(Surge.connected_clients)
        @test isempty(Surge.signal_map)
        
        # Verify servers stopped
        @test server.state == :failed
    end
end
