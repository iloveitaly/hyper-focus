import Telegraph

class ApiServer {
  init() {
    // TODO public docs were incorrect here and the dependency snippet didn't include from:, add it
    let server = Server()
    server.route(.GET, "ping") { (.ok, "Server is running") }
    try! server.start(port: 9000)

    if !server.isRunning {
      log("Server failed to start")
      return
    }

    log("Server started on port 9000")
  }
}