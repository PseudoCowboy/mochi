import XCTest
import BackgroundTasks
import SwiftUI
@testable import Mochi_iOS

final class ContentViewBackgroundToggleTests: XCTestCase {
    
    var defaults: UserDefaults!
    let defaultsKey = "summaryBackgroundEnabled"
    
    // Simulate the View's state binding
    struct ViewState {
        @AppStorage("summaryBackgroundEnabled") var bgEnabled: Bool
        
        init(defaults: UserDefaults) {
            _bgEnabled = AppStorage(wrappedValue: true, "summaryBackgroundEnabled", store: defaults)
        }
    }
    
    override func setUp() {
        super.setUp()
        // Uses an isolated UserDefaults(suiteName:) per test to avoid cross-test bleed
        defaults = UserDefaults(suiteName: "ContentViewBackgroundToggleTests")
        defaults.removePersistentDomain(forName: "ContentViewBackgroundToggleTests")
    }
    
    override func tearDown() {
        defaults.removePersistentDomain(forName: "ContentViewBackgroundToggleTests")
        defaults = nil
        super.tearDown()
    }
    
    func testBackgroundToggleMutatesUserDefaults() {
        var state = ViewState(defaults: defaults)
        
        // Default is true
        XCTAssertTrue(state.bgEnabled)
        XCTAssertNil(defaults.object(forKey: defaultsKey)) // Absent key still yields true wrappedValue
        
        // Simulating the Toggle flipping to false
        state.bgEnabled = false
        XCTAssertFalse(defaults.bool(forKey: defaultsKey), "Toggling the control should mutate UserDefaults to false")
        
        // Simulating the Toggle flipping to true
        state.bgEnabled = true
        XCTAssertTrue(defaults.bool(forKey: defaultsKey), "Toggling the control should mutate UserDefaults to true")
    }
    
    func testDefaultValueIsTrueWhenKeyIsAbsent() {
        XCTAssertNil(defaults.object(forKey: defaultsKey)) // Absent key
        
        let scheduler = FakeBGTaskScheduler()
        // Assumes Atlas adds an internal overload taking both scheduler and defaults
        SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)
        
        XCTAssertEqual(scheduler.submittedRequests.count, 1, "Should attempt a submit when key is absent (defaults to true)")
        XCTAssertEqual(scheduler.submittedRequests.first?.identifier, "com.pseudocowboy.mochi.summary.refresh")
    }
    
    func testScheduleNextDoesNotSubmitWhenFalse() {
        defaults.set(false, forKey: defaultsKey)
        
        let scheduler = FakeBGTaskScheduler()
        SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)
        
        XCTAssertTrue(scheduler.submittedRequests.isEmpty, "Should not attempt a submit when key is false")
    }
    
    func testScheduleNextSubmitsWhenTrue() {
        defaults.set(true, forKey: defaultsKey)
        
        let scheduler = FakeBGTaskScheduler()
        SummaryWriter.scheduleNext(scheduler: scheduler, defaults: defaults)
        
        XCTAssertEqual(scheduler.submittedRequests.count, 1, "Should attempt a submit when key is true")
        XCTAssertEqual(scheduler.submittedRequests.first?.identifier, "com.pseudocowboy.mochi.summary.refresh")
    }
}
