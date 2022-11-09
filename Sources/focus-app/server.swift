import Ambassador
import Embassy
import Foundation
import Telegraph

var server: Server?

// because I don't want to learn how to receive applescript events, and because I know
// web technologies well, I decided to expose a http interface to the application instead
// applescript, swiftui, etc.

class ApiServer {
  let scheduleManager: ScheduleManager
  let serverPort = 9029

  // TODO: not used! Telegraph is a better server, but I did not realize how to get it working until later
  // http -vvv GET http://localhost:8081/ping
  func telegraphServer() {
    server = Server()
    guard let unwrappedServer = server else {
      return
    }
    unwrappedServer.route(.GET, "/ping") { (.ok, "Server is running") }
    unwrappedServer.route(.GET, "ping") { (.ok, "Server is running") }

    do {
      try unwrappedServer.start(port: 8081, interface: "localhost")
      unwrappedServer.route(.GET, "/ping") { (.ok, "Server is running") }
      unwrappedServer.route(.GET, "ping") { (.ok, "Server is running") }
      print("started server")
    } catch {
      print("Server start error: \(error)")
    }
  }

  init(scheduleManager: ScheduleManager) {
    self.scheduleManager = scheduleManager

    // must run in separate thread or it will block the main event loop
    Task {
      let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
      let router = Router()
      let server = DefaultHTTPServer(eventLoop: loop, port: serverPort, app: router.app)

      // https://github.com/envoy/Ambassador/blob/master/Ambassador/Responses/JSONResponse.swift

      router["/ping"] = JSONResponse { _ -> Any in
        ["status": "ok"]
      }

      router["/status"] = JSONResponse { _ -> [String: Dictionary] in
        let currentSchedule = self.scheduleManager.plannedSchedule
        var scheduledUntil: Int?

        if currentSchedule != nil {
          let nowWithStartAndEnd = Calendar.current.date(
            bySettingHour: currentSchedule!.start!,
            minute: currentSchedule!.end!,
            second: 0,
            of: Date()
          )!

          scheduledUntil = Int(nowWithStartAndEnd.timeIntervalSince1970)
        }

        return [
          "schedule": [
            "name": self.scheduleManager.plannedSchedule?.name,
            "until": scheduledUntil
          ],
          "override": [
            "until": self.scheduleManager.endOverride?.timeIntervalSince1970,
            "name": self.scheduleManager.overrideSchedule?.name,
          ],
          "pause": [
            "until": self.scheduleManager.endPause?.timeIntervalSince1970,
          ]
        ]
      }

      router["/configurations"] = JSONResponse { _ -> Any in
        self.scheduleManager.namedSchedules().map { $0.name }
      }

      // http -vvv POST http://localhost:8080/override name='hyper focus' until=1667514400
      router["/override"] = JSONResponse { environ -> Any in
        log("/override")

        var pauseUtil: Int?
        var scheduleName: String?

        let input = environ["swsgi.input"] as! SWSGIInput
        JSONReader.read(input) { json in
          guard let receivedData: [String: Any] = json as? [String: Any] else {
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
      router["/pause"] = JSONResponse { environ -> Any in
        log("pause route")

        var pauseUtil: Int?

        let input = environ["swsgi.input"] as! SWSGIInput
        JSONReader.read(input) { json in
          guard let receivedData: [String: Any] = json as? [String: Any] else {
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
