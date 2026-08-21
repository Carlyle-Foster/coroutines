// use `nc localhost 8783` or similar to talk to this server
package echo

import "core:fmt"
import "core:strings"
import "core:nbio"

import co "../../../coro"

main :: proc() {
    nbio.acquire_thread_event_loop()
    defer nbio.release_thread_event_loop()

    socket, listen_err := nbio.listen_tcp({nbio.IP4_Any, 8783})
    ensure(listen_err == nil)

    co.accept(socket, handle_client, on_accept_err)

    err := nbio.run()

    ensure(err == nil)
}

handle_client :: proc(cc: co.Caller, client: nbio.TCP_Socket, endpoint: nbio.Endpoint) {
    fmt.println("client opened connection")

    buf: [4096]byte
    for {
        read, recv_err := co.recv(cc, client, {buf[:]})
        ensure(recv_err == nil)
        if read == 0 {
            fmt.println("client closed connection")
            return
        }
        fmt.println("received", read, "byte message:", strings.trim_space(string(buf[:read])))
    
        writ, send_err := co.send(cc, client, {buf[:read]})
        ensure(send_err == nil)
        if writ == 0 {
            fmt.println("client closed connection")
            return
        }
        fmt.println("sent", writ, "bytes in return:", strings.trim_space(string(buf[:writ])))
    }
}

on_accept_err :: proc(cc: co.Caller, err: nbio.Error) {
    fmt.println("Error acceptng client: ", err)
}