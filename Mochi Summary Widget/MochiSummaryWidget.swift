import WidgetKit
import SwiftUI

struct MochiSummaryWidget: Widget {
    let kind: String = "MochiSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Calm")
        .description("Your daily summary of calm and over minutes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
