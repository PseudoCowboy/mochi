import Foundation
import BackgroundTasks
@testable import Mochi_iOS

final class FakeBGTaskScheduler: BGTaskSchedulerProtocol {
    struct RegisterCall {
        let identifier: String
        let queue: DispatchQueue?
        let handler: (BGTask) -> Void

        var launchHandler: (BGTask) -> Void { handler }
    }

    private(set) var registerCalls: [RegisterCall] = []
    private(set) var submittedRequests: [BGTaskRequest] = []
    var registerReturnValue: Bool = true
    var submitError: Error?

    @discardableResult
    func register(
        forTaskWithIdentifier identifier: String,
        using queue: DispatchQueue?,
        launchHandler: @escaping (BGTask) -> Void
    ) -> Bool {
        registerCalls.append(.init(identifier: identifier, queue: queue, handler: launchHandler))
        return registerReturnValue
    }

    func submit(_ taskRequest: BGTaskRequest) throws {
        if let submitError {
            throw submitError
        }
        submittedRequests.append(taskRequest)
    }
}

final class FakeBGAppRefreshTask: RefreshTaskCompletable {
    var expirationHandler: (() -> Void)?
    private(set) var completionResults: [Bool] = []
    var lastCompletionSuccess: Bool? { completionResults.last }

    func setTaskCompleted(success: Bool) {
        completionResults.append(success)
    }
}
