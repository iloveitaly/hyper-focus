import Telegraph

class ApiServer {
  init() {
    // set NSExceptionAllowsInsecureHTTPLoads = true directly in memory
    // https://stackoverflow.com/questions/31254725/transport-security-has-blocked-a-cleartext-http



    // TODO public docs were incorrect here and the dependency snippet didn't include from:, add it
    let server = Server()
    server.route(.GET, "ping") { (.ok, "Server is running") }

    // https://github.com/nginx-proxy/nginx-proxy/issues/1059
    // POST endpoint /configuration accepting parameter 'schedule_name' and 'duration'
    // server.route(.POST, "configuration") { request -> (HTTPStatusCode, String) in
    //   guard let scheduleName = request.formValue("schedule_name"),
    //         let duration = request.formValue("duration") else {
    //     return (.badRequest, "Missing schedule_name or duration")
    //   }

    //   // change the schedule of the schedule manager
    //   // scheduleManager.changeSchedule(scheduleName: scheduleName, duration: duration)
    // }

    // https://github.com/Building42/Telegraph/pull/5
    // try! server.start(port: 9000, interface: "loopback")
    // try! server.start(port: 9000, interface: "127.0.0.1")
    // server.start(port: 9000, interface: "localhost")
    do {
      // using `port: 0` will automatically select a random port
      // try server.start(port: 0, interface: "loopback")
      // try server.start(port: 0, interface: "loopback")
      Task{
      try server.start(port: 9001, interface: "localhost")
      server.route(.GET, "ping") { (.ok, "Server is running") }
      }
      // try server.start(port: 9000)
    } catch {
      print("Error starting server: \(error)")
    }

    if !server.isRunning {
      log("Server failed to start")
      return
    }

    log("Server started on port \(server.port) \(server.isSecure)")
  }
}