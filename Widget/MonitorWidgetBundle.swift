import SwiftUI
import WidgetKit

@main
struct MonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        MonitorHomeWidget()
        MonitorLiveActivity()
    }
}
