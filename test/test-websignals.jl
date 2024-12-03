using Test
using Surge
using HTTP
using JSON
using StateSignals

@testset "Surge tests" begin
    @testset "Signal attachment" begin
        # Create and attach a signal
        counter = Signal(0, :counter)
        attached = attach_websocket(counter)
        
        # Test that signal was added to signal_map
        @test haskey(Surge.signal_map, counter.id)
        @test Surge.signal_map[counter.id] === counter
    end

    @testset "WebSocket server" begin
        # Start server on test port
        test_port = 8082
        server = start_websocket_server(test_port)
        
        # Create test signal
        counter = Signal(42, :test_counter)
        attach_websocket(counter)
        
        # Connect test client
        client = HTTP.WebSockets.open("ws://127.0.0.1:$test_port") do ws
            # Should receive initial state
            msg = JSON.parse(String(HTTP.WebSockets.receive(ws)))
            @test msg["type"] == "update"
            @test msg["id"] == "test_counter"
            @test msg["value"] == 42
            
            # Test sending update from client
            update_msg = JSON.json(Dict(
                "type" => "update",
                "id" => "test_counter",
                "value" => 100
            ))
            HTTP.WebSockets.send(ws, update_msg)
            
            # Wait briefly for update to process
            sleep(0.1)
            
            # Verify signal was updated
            @test counter() == 100
            
        end
        
        # Clean up
        Base.schedule(server, InterruptException(); error=true)
    end

    @testset "Server start/stop" begin
        # Start both servers
        servers = start_server(8083)
        
        # Verify servers are running
        @test servers.http.state == :runnable
        @test servers.websocket.state == :runnable
        
        # Create and attach test signal
        test_signal = Signal("test", :test)
        attach_websocket(test_signal)
        
        # Stop servers and verify cleanup
        stop_server(servers)
        
        # Verify cleanup
        @test isempty(Surge.client_sockets)
        @test isempty(Surge.signal_map)
        
        # Verify servers stopped
        @show servers.http.state
        @show servers.websocket.state
        @test servers.http.state == :failed
        @test servers.websocket.state == :failed
    end
end
