import Embassy
import Ambassador
import Foundation

class ApiServer {
  let scheduleManager: ScheduleManager

  init(scheduleManager: ScheduleManager) {
    self.scheduleManager = scheduleManager

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