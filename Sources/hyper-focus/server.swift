import Ambassador
import Embassy
import Foundation

// because I don't want to learn how to receive applescript events, and because I know
// web technologies well, I decided to expose a http interface to the application instead
// applescript, swiftui, etc.

class ApiServer {
    let scheduleManager: ScheduleManager
    let serverPort = 9029

    init(scheduleManager: ScheduleManager) {
        self.scheduleManager = scheduleManager

        // must run in separate thread or it will block the main event loop
        Task {
            let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
            let router = Router()
            let server = DefaultHTTPServer(eventLoop: loop, port: serverPort, app: router.app)

            // https://github.com/envoy/Ambassador/blob/master/Ambassador/Responses/JSONResponse.swift
            // all API endpoints are exposed below

            router["/ping"] = JSONResponse { _ -> Any in
                ["status": "ok"]
            }

            router["/status"] = JSONResponse { _ -> [String: Dictionary] in
                let plannedSchedule = self.scheduleManager.plannedSchedule
                var scheduledUntil: Int?

                if plannedSchedule != nil {
                    // special case last hour, otherwise date will be empty
                    let isLastHour = plannedSchedule!.end! == 24

                    let nowWithStartAndEnd = Calendar.current.date(
                        bySettingHour: isLastHour ? 23 : plannedSchedule!.end!,
                        minute: isLastHour ? 59 : 0,
                        second: 0,
                        of: Date()
                    )!

                    scheduledUntil = Int(nowWithStartAndEnd.timeIntervalSince1970)
                }

                return [
                    "schedule": [
                        "name": self.scheduleManager.plannedSchedule?.name,
                        "until": scheduledUntil,
                    ] as [String: Any?],
                    "override": [
                        "until": self.scheduleManager.endOverride?.timeIntervalSince1970,
                        "name": self.scheduleManager.overrideSchedule?.name,
                    ],
                    "pause": [
                        "until": self.scheduleManager.endPause?.timeIntervalSince1970,
                    ],
                ]
            }

            router["/reload"] = JSONResponse { _ -> [String: String] in
                self.scheduleManager.reloadConfiguration()
                return ["status": "ok"]
            }

            // http http://localhost:8080/override
            // return all schedules and let the frontend deal with formatting and filtering
            router["/schedules"] = JSONResponse { _ -> Any in
                let rawSchedules = self.scheduleManager.schedules()

                // TODO: there's got to be a better way to convert a codable object to JSON
                let schedules: [[String: Any]] = rawSchedules.map { schedule in
                    let jsonData = try! JSONEncoder().encode(schedule)
                    let json = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
                    return json
                }

                return schedules
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

            router["/resume"] = JSONResponse { _ -> Any in
                log("/resume")
                self.scheduleManager.resumeBlocking()
                return ["status": "ok"]
            }

            // http -vvv POST http://localhost:8080/pause until=1667510271
            router["/pause"] = JSONResponse { environ -> Any in
                log("/pause")

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
