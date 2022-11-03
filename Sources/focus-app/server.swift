import Embassy
import Ambassador
import Foundation
import Telegraph

class ApiServer {
  let scheduleManager: ScheduleManager

  // http -vvv GET http://localhost:8081/ping
  func old() {
    let server = Server()
    server.route(.GET, "/ping") { (.ok, "Server is running") }
    server.route(.GET, "ping") { (.ok, "Server is running") }

    Task {
      do {
        try server.start(port: 8081, interface: "localhost")
        server.route(.GET, "/ping") { (.ok, "Server is running") }
        server.route(.GET, "ping") { (.ok, "Server is running") }
        print("started server")
      } catch {
        print("Server start error: \(error)")
      }
    }
  }

  init(scheduleManager: ScheduleManager) {
    self.scheduleManager = scheduleManager

    old()
    Task {
      let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
      let router = Router()
      let server = DefaultHTTPServer(eventLoop: loop, port: 8080, app: router.app)

      router["/pause"] = JSONResponse() { environ -> Any in
        let input = environ["swsgi.input"] as! SWSGIInput

        var receivedData: [String: Int];
        JSONReader.read(input) { json in
          guard let receivedData = json as? [String: Int] else {
            return
          }

          print("Received data: \(json)")
          // let timestamp = json["until"] as! Int

          // 5 minutes from now
          let fiveMinutesFromNow = Date().addingTimeInterval(60 * 5)
          self.scheduleManager.pauseBlocking(fiveMinutesFromNow)
        }

        // return empty dictionary
        return [:]

        // return ["hi"]
      }

      // Start HTTP server to listen on the port
      try! server.start()

      // Run event loop
      loop.runForever()
    }
  }
}