import SwiftUI
import WidgetKit

struct StressPetComplication: Widget {
    let kind: String = "StressPetComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            StressPetComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
        .configurationDisplayName("Mochi Pet")
        .description("Your StressPet at a glance.")
    }
}
