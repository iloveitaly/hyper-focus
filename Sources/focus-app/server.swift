import Telegraph
import Embassy
import Foundation

class ApiServer {
  let scheduleManager: ScheduleManager

  init(scheduleManager: ScheduleManager) {
    self.scheduleManager = scheduleManager

    Task {
      let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
      let server = DefaultHTTPServer(eventLoop: loop, port: 8080) {
          (
              environ: [String: Any],
              startResponse: ((String, [(String, String)]) -> Void),
              sendBody: ((Data) -> Void)
          ) in

          let input = environ["swsgi.input"] as! SWSGIInput
          input { data in
              print("Received data: \(data)")
              // handle the body data here
          }

          startResponse("200 OK", [])
          sendBody(Data("the path you're visiting is \(environ)".utf8))
          sendBody(Data())

          // 5 minutes from now
          let fiveMinutesFromNow = Date().addingTimeInterval(60 * 5)
          self.scheduleManager.pauseBlocking(fiveMinutesFromNow)
      }

      // Start HTTP server to listen on the port
      try! server.start()

      // Run event loop
      loop.runForever()
    }
  }
}