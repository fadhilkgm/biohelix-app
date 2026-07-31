import Flutter
import HealthKit
import UIKit

final class HealthKitFitnessPlugin: NSObject {
  private static let channelName = "com.biohelix.app/fitness"

  private let healthStore = HKHealthStore()
  private let calendar = Calendar.current

  private var readTypes: Set<HKObjectType> {
    [
      HKObjectType.quantityType(forIdentifier: .stepCount),
      HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
      HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
    ].compactMap { $0 }.reduce(into: Set<HKObjectType>()) { $0.insert($1) }
  }

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "HealthKitFitnessPlugin") else {
      return
    }
    let instance = HealthKitFitnessPlugin()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler(instance.handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      getStatus(result: result)
    case "requestPermissions":
      requestPermissions(result: result)
    case "readActivity":
      let arguments = call.arguments as? [String: Any]
      let requestedDays = min(max(arguments?["days"] as? Int ?? 7, 1), 7)
      readActivity(days: requestedDays, result: result)
    case "openHealthConnect":
      openHealthSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getStatus(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(statusPayload(permissionsGranted: false, available: false))
      return
    }

    healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) {
      status, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "healthkit_status",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(self.statusPayload(
          permissionsGranted: status != .shouldRequest,
          available: true
        ))
      }
    }
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(
        FlutterError(
          code: "healthkit_unavailable",
          message: "Apple Health data is unavailable on this device.",
          details: nil
        )
      )
      return
    }

    healthStore.requestAuthorization(toShare: [], read: readTypes) {
      success, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "healthkit_permission",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(["granted": success])
      }
    }
  }

  private func readActivity(days: Int, result: @escaping FlutterResult) {
    guard HKHealthStore.isHealthDataAvailable() else {
      result(
        FlutterError(
          code: "healthkit_unavailable",
          message: "Apple Health data is unavailable on this device.",
          details: nil
        )
      )
      return
    }

    let today = calendar.startOfDay(for: Date())
    let group = DispatchGroup()
    let lock = NSLock()
    var output = Array(repeating: [String: Any](), count: days)
    var firstError: Error?

    for index in 0..<days {
      guard let date = calendar.date(
        byAdding: .day,
        value: index - (days - 1),
        to: today
      ), let end = calendar.date(byAdding: .day, value: 1, to: date) else {
        continue
      }

      group.enter()
      readDay(start: date, end: end) { values, error in
        lock.lock()
        if let error, firstError == nil {
          firstError = error
        }
        output[index] = [
          "date": Self.dateFormatter.string(from: date),
          "steps": Int(values.steps.rounded()),
          "activeCalories": values.activeCalories,
          "distanceMeters": values.distanceMeters,
        ]
        lock.unlock()
        group.leave()
      }
    }

    group.notify(queue: .main) {
      if let firstError {
        result(
          FlutterError(
            code: "healthkit_read",
            message: firstError.localizedDescription,
            details: nil
          )
        )
        return
      }
      result([
        "timezone": TimeZone.current.identifier,
        "days": output,
      ])
    }
  }

  private func readDay(
    start: Date,
    end: Date,
    completion: @escaping (ActivityValues, Error?) -> Void
  ) {
    let group = DispatchGroup()
    let lock = NSLock()
    var values = ActivityValues()
    var firstError: Error?

    let requests: [(HKQuantityTypeIdentifier, HKUnit, (Double) -> Void)] = [
      (.stepCount, .count(), { values.steps = $0 }),
      (.activeEnergyBurned, .kilocalorie(), { values.activeCalories = $0 }),
      (.distanceWalkingRunning, .meter(), { values.distanceMeters = $0 }),
    ]

    for (identifier, unit, assign) in requests {
      guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
        continue
      }
      group.enter()
      let predicate = HKQuery.predicateForSamples(
        withStart: start,
        end: end,
        options: .strictStartDate
      )
      let query = HKStatisticsQuery(
        quantityType: type,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, statistics, error in
        lock.lock()
        if let error, firstError == nil {
          firstError = error
        }
        assign(statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0)
        lock.unlock()
        group.leave()
      }
      healthStore.execute(query)
    }

    group.notify(queue: .global(qos: .userInitiated)) {
      completion(values, firstError)
    }
  }

  private func openHealthSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { success in
      result(success)
    }
  }

  private func statusPayload(
    permissionsGranted: Bool,
    available: Bool
  ) -> [String: Any] {
    [
      "status": available ? "available" : "unavailable",
      "permissionsGranted": permissionsGranted,
      "nativePhoneStepTracking": true,
      "androidVersion": 0,
    ]
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

private struct ActivityValues {
  var steps = 0.0
  var activeCalories = 0.0
  var distanceMeters = 0.0
}
