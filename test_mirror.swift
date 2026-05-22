import SwiftUI

struct MyView: View {
    @AppStorage("myKey") private var enabled = true
    var body: some View { Text("Hi") }
}

let v = MyView()
let mirror = Mirror(reflecting: v)
for child in mirror.children {
    print("\(child.label ?? ""): \(type(of: child.value))")
}
