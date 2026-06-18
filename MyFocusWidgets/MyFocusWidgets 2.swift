#if !SWIFT_PACKAGE
import WidgetKit
import SwiftUI

@main
struct MyFocusWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        TimeRemainingWidget()
    }
}
#endif
