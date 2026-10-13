# Architecture

Activity Monitor targets iOS 17 and later. `project.yml` is the source of truth for Xcode targets; run `xcodegen generate` after changing sources or dependencies.

## Compile-time modules

The local `Packages/MonitorKit` package has no external dependencies.

| Product | Responsibility | Dependencies |
| --- | --- | --- |
| MonitorDomain | Snapshot models, battery/thermal/network statuses, metric selection and persistence | Foundation |
| MonitorTelemetry | Darwin host CPU/RAM sampling and validated tick calculations | Foundation, Darwin |
| MonitorActivity | Codable ActivityKit attributes and snapshot-to-payload mapping | MonitorDomain, ActivityKit |

The application and widget extension explicitly link these products. Shared Swift files are compiled by the package rather than included independently in both targets. Only consumer-facing types are public; raw CPU tick calculations remain internal and are covered through `@testable import MonitorTelemetry`.

## Application

- `Sources/App`: application composition and scene lifecycle.
- `Sources/Services`: foreground sampling, history/export, network monitoring and ActivityKit lifecycle. These app services remain outside the extension-safe shared package.
- `Sources/UI/Features`: Dashboard, Details, History and Settings screens.
- `Sources/UI/Components`: reusable gauges and original-frame battery animation.
- `Sources/UI/DesignSystem`: colors, localization presentation and number transition styling.
- `Sources/Resources`: localization, asset catalog and original exported battery frames. `Resource` retains original design source files.

Views consume snapshots; the app owns sampling and scene transitions. Domain models do not depend on SwiftUI, UIKit or WidgetKit. The telemetry module does not depend on views or ActivityKit.

## Widget extension

Home Screen timeline acquisition/configuration stays separate from presentation components. Live Activity presentation consumes the shared ActivityKit state; it does not own sampling. Home Screen configuration is per widget instance. App metric selection is persisted by MonitorDomain.

Foreground Live Activity writes are throttled to about 10 seconds. Background transition retains the last sample; there is no periodic background refresh. Home widgets request a 30-minute timeline refresh, scheduled by iOS. Capture timestamps remain authoritative across stale entries and configuration changes.

## Validation

The application XCTest target covers domain normalization, storage validation, ActivityKit serialization/lifecycle scope and system telemetry calculations. `Scripts/verify-home-widget-model.py` checks the actual extracted timeline-entry model; localization and resource scripts verify all four locales and original animation frames. Simulator host CPU/RAM/disk readings describe the Mac host, not a physical iPhone.

Refactoring keeps bundle identifiers, layouts, original battery frames, colors, number-jump transitions and thermal fill proportions (50/70/85/100 percent) unchanged.
