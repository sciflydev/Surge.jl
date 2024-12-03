using Surge

counter = Signal(0,:counter)
countertwo = Signal(6,:countertwo)
total = computed(() -> counter() + countertwo(), :total)
word = Signal("hello", :word)


effect(() -> println("Counter updated to ", counter()))
effect(() -> println("Countertwo updated to ", countertwo()))
effect(() -> println("Total is ", total()))

map(attach_websocket, [counter, countertwo, total, word])
server=start_server(8080)

