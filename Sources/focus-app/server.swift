import Embassy
import Ambassador
import Foundation
import Telegraph

class ApiServer {
  let scheduleManager: ScheduleManager

  // TODO not used!
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

    // must run in separate thread or it will block the main event loop
    Task {
      let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
      let router = Router()
      let server = DefaultHTTPServer(eventLoop: loop, port: 8080, app: router.app)

      // https://github.com/envoy/Ambassador/blob/master/Ambassador/Responses/JSONResponse.swift

      router["/ping"] = JSONResponse() { _ -> Any in
        return ["status": "ok"]
      }

      router["/configurations"] = JSONResponse() { _ -> Any in
        return self.scheduleManager.namedSchedules().map { $0.name }
      }

      // http -vvv POST http://localhost:8080/override name='hyper focus' until=1667514400
      router["/override"] = JSONResponse() { environ -> Any in
        var pauseUtil: Int?
        var scheduleName: String?

        let input = environ["swsgi.input"] as! SWSGIInput
        JSONReader.read(input) { json in
          guard let receivedData: [String : Any] = json as? [String: Any] else {
            return
          }

          if let until = receivedData["until"] as? Int {
            pauseUtil = until
          } else if let until = receivedData["until"] as? String {
            pauseUtil = Int(until)
          }

          scheduleName = receivedData["name"] as? String
        }

        if scheduleName == nil || pauseUtil == nil {
          return ["error": "missing parameters"]
        }

        let end = Date(timeIntervalSince1970: TimeInterval(pauseUtil!))

        self.scheduleManager.scheduleOverride(
          name: scheduleName!,
          end: end
        )

        return ["status": "ok"]
      }

      // http -vvv POST http://localhost:8080/pause until=1667510271
      router["/pause"] = JSONResponse() { environ -> Any in
        var pauseUtil: Int?

        let input = environ["swsgi.input"] as! SWSGIInput
        JSONReader.read(input) { json in
          guard let receivedData: [String : Any] = json as? [String: Any] else {
            return
          }

          // handle receivedData["until"] being a string or int
          if let until = receivedData["until"] as? Int {
            pauseUtil = until
          } else if let until = receivedData["until"] as? String {
            pauseUtil = Int(until)
          }
        }

        guard pauseUtil != nil else {
          return ["status": "error", "message": "missing integer until param"]
        }

        // convert pauseUtil to date
        let untilDate = Date(timeIntervalSince1970: TimeInterval(pauseUtil!))
        self.scheduleManager.pauseBlocking(untilDate)

        return ["status": "ok"]
      }

      try! server.start()
      loop.runForever()
    }
  }
}