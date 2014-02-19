# Hoosegow dispatch

Calling a method on an inmate involves passing information through several layers. The participants in the flow are:

* **Proxy** - Outside a docker container, the app calls a method on a `Hoosegow` instance. The `Hoosegow` object acts as a proxy for another `Hoosegow` instance running inside a docker container.
* **Docker** - The caller makes an HTTP POST request to docker to attach to a container. The body of the request contains `STDIN` for the process. Docker multiplexes `STDOUT` and `STDERR` in the response body.
* **bin/hoosegow** - This is the script that receives `STDIN` and produces `STDOUT` and `STDERR`.
* **Inmate** - Inside the docker container, the inmate code receives a method call.

 Proxy                  Docker        bin/hoosegow(1)     bin/hoosegow(2)              Inmate

   |                      |                 |                   |                        |
   | HTTP POST /attach    |                 |                   |                        |
   |--------------------->|                 |                   |                        |
   | msgpack(method,args) |---------------->|                   |                        |
   |                      | stdin           |------------------>|                        |
   |                      |                 | stdin             | send(method,args,&blk) |
   |                      |                 |                   |----------------------->|
   |                      |                 |                   |                        |
   |                      |                 |                   |                        |
   |                      |                 |                   |<-----------------------|
   |                      |                 |                   | result,                |
   |                      |                 |<------------------| blk.call(),            |
   |                      |                 | stdout,           | stdout,                |
   |                      |                 | stderr,           | stderr                 |
   |                      |                 | sidechannel=      |                        |
   |                      |                 |   encode(         |                        |
   |                      |<----------------|     blk.call(),   |                        |
   |                      | stderr,         |     result)       |                        |
   | 200 OK               | stdout=encode(  |                   |                        |
   |<---------------------|   stdout,       |                   |                        |
   | multiplex(stdout,    |   callbacks,    |                   |                        |
   |   stderr)            |   result)       |                   |                        |
   |                      |                 |                   |                        |

## Interfaces

### Proxy

The outer instance of `Hoosegow` receives a normal call from the application.

It encodes the method name and arguments and provides that to an attach call to Docker.

It reads the Docker response as it comes in. It demultiplexes the docker output into `STDERR` and `STDOUT`. `STDOUT` is further decoded into the actual `STDOUT` from the Inmate, `yield` calls, and the method result.

### Docker

Docker receives an HTTP POST with a body, and returns an HTTP response with a body. The HTTP request body is treated as `STDIN`, and the response body contains `STDOUT` and `STDERR`.

See [documentation for attach](http://docs.docker.io/en/latest/reference/api/docker_remote_api_v1.7/#attach-to-a-container).

### bin/hoosegow(1)

The outer invocation of `bin/hoosegow` is started by Docker when the container starts. It is the entry point of the container.

It runs itself again, and passes another pipe (sidechannel) to the child process.

`STDERR` is left as-is. `STDOUT` from `bin/hoosegow`(2) and the sidechannel are encoded into the `STDOUT` that Docker sees.

### bin/hoosegow(2)

The inner invocation of `bin/hoosegow` decodes stdin and calls the requested method on the Inmate.

`STDOUT` and `STDERR` are left as-is. When the Inmate yields or returns, the information is encoded on the sidechannel.

### Inmate

The Inmate is an object that includes the `Hoosegow::Inmate` module.

Input to the Inmate is a method name and arguments.

Output from the Inmate can be spread across several things:

* `STDOUT` and `STDERR` - e.g. puts calls 
* `yield` to a block
* the result of the method
