package echo

import "core:fmt"
import "core:net"
import "core:strings"

import "core:sys/linux"

import coroutine "../../../coroutines"

HOST :: "localhost"
PORT :: "8783"

quit := false
server_id := 0

main :: proc() {
    server_id = coroutine.id()

    endpoint, _, resolve_err := net.resolve(HOST + ":" + PORT)
    assert(resolve_err == nil)

    server, network_err := net.listen_tcp(endpoint)
    assert(network_err == nil)
    
    server_set_blocking_error := net.set_blocking(server, should_block=false)
    assert(server_set_blocking_error == nil)

    fmt.printfln("[%v] Server listening to %v:%v", coroutine.id(), HOST, PORT)
    SERVER: for {
        coroutine.sleep_read(linux.Fd(server))
        if quit {
            break SERVER
        }
        client, _, accept_err := net.accept_tcp(server)
        assert(accept_err == nil)

        client_set_blocking_error := net.set_blocking(client, should_block=false)
        assert(client_set_blocking_error == nil)

        coroutine.go(proc(arg: rawptr) {
            fmt.printfln("[%v] Client connected!", coroutine.id())

            client := net.TCP_Socket(uintptr(arg))
            defer {
                net.shutdown(client, .Both)
                net.close(client)
            }

            buf: [4096]byte

            CLIENT: for {
                coroutine.sleep_read(linux.Fd(client))
                n, recv_err := net.recv_tcp(client, buf[:])
                if recv_err != nil {
                    fmt.printfln("[%v] Error when receiving from client: %v", coroutine.id(), recv_err)
                    break CLIENT
                }
                
                if (n == 0) { // the client closed the connection
                    break CLIENT
                }

                chunk: = buf[:n]

                switch strings.trim(string(chunk), " \t\r\n") {
                    case "quit":
                        fmt.printfln("[%v] Client requested to quit", coroutine.id())
                        return
                    case "shutdown":
                        fmt.printfln("[%v] Client requested to shutdown the server", coroutine.id())
                        quit = true
                        coroutine.wake_up(server_id)
                        return
                }

                fmt.printfln("[%v] Client sent %v bytes", coroutine.id(), len(chunk))

                for len(chunk) > 0 {
                    coroutine.sleep_write(linux.Fd(client))
                    m, send_err := net.send_tcp(client, chunk)
                    assert(send_err == nil)
                    if m == 0 {
                        break CLIENT
                    }
                    chunk = chunk[m:]
                }
            }
            fmt.printfln("[%v] Client disconnected", coroutine.id())
        }, rawptr(uintptr(client)))
    }
    fmt.printfln("[%v] Server has been shutdown", coroutine.id())
}
