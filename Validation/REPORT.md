# Activity Monitor validation — 2026-10-11

## Delivered

Native iOS 17+ SwiftUI app and WidgetKit Live Activity, with no watchOS target. Main bundle `com.invivo.ios.Activity-Monitor`; extension `com.invivo.ios.Activity-Monitor.LiveActivity`. Sol directed the design/checklist and reviewed integration; Luna built UI/localization; Astra implemented telemetry, ActivityKit and core tests. The primary agent integrated and performed runtime validation.

Includes battery/charging, Low Power Mode, thermal state, disk capacity, physical RAM, App CPU and memory, network connection/interface rates and cumulative counters, a bounded 300-sample session history, refresh, clear history, CSV export, and Live Activity start/stop. CPU and memory are explicitly this app's measurements. Network counters are not internet bandwidth or carrier billing usage.

## Design evidence

All 1,173 original battery PNGs were copied without alteration and verified by SHA-256. Each charge band uses 31 entrance frames and 360 loop frames at 30 fps (1.033-second entrance and 12-second loop). Original battery frame, yellow dial/pin and icon artwork are bundled. The wide dashboard wave field is a native two-layer adaptation of the supplied style, not an exported original sequence. Gauge dimensions retain source aspect ratios.

`battery-animation-preview.mp4` records app restart, empty-to-filled entrance and moving double liquid contours. `animation-battery-sequence.png` samples the recording every 0.25 seconds; visual inspection confirmed the rise and changing wave shapes over more than one loop. The initial recording includes the previous screen/home/launch transition. Timing and source fidelity are verified; physical-device frame pacing and power cost are not.

Four final dashboard screenshots were inspected: `dashboard-en-preview.png`, `dashboard-zh-Hant-preview.png`, `dashboard-zh-Hans-preview.png`, `dashboard-ja-preview.png`. They show 95%, 68%, 12%, 95% battery fixtures respectively, explicitly labelled as DEBUG design previews. Other readings remain live Simulator measurements. Fixtures are excluded from Release; binary inspection confirmed the `--design-preview` flag is absent.

## Passed checks

- Debug iOS Simulator app + embedded extension build (`debug-build.log`). Installed and launched the final binary on iPhone 17 / iOS 27.
- Release generic iOS arm64 build with signing disabled (`release-build.log`). This is compile proof, not a signed device install or App Store archive.
- Five focused XCTest tests, zero failures (`core-tests.log`): unavailable/clamped storage, CPU/network rate baselines, suspension/reset handling, CSV values/scope and ActivityKit payload/staleness.
- Main localization tables: 116 keys in each of en, zh-Hant, zh-Hans, ja. Widget: 9 keys in each language. Key parity, duplicate and literal/dynamic key coverage checks pass (`localization-integrity.txt`).
- Source animation integrity and sequence counts pass (`resource-integrity.txt`).
- Actual menu navigation to Details, History and Settings. Details displayed scoped real readings. Simulator reports host hardware values, such as Mac RAM/storage; these are not physical iPhone readings.
- History populated with live CPU samples; picker labels render in Traditional Chinese. Shortened chart time labels fit without the earlier overlap (`history-cpu-zh-Hant.png`). Unavailable battery uses the empty state in normal Simulator mode.
- Settings refresh, CSV generation and native ShareLink share sheet were observed. No export was sent to another application or service. CSV excludes storage and boot-time readings. The final export explanation is visible in `settings-zh-Hant.png`.
- Live Activity Start changed status to running; Stop changed it back to inactive. Background transition produced the paused status, retaining the last timestamp.
- Compact Dynamic Island battery/paused state was observed in Device Hub. Its host overlay is omitted by `simctl screenshot`, so no standalone screenshot is claimed as Island proof.
- Lock Screen Live Activity rendered the green battery, yellow CPU/memory dial, cyan network values and paused timestamp (`live-activity-lockscreen-preview.png`). This screenshot uses DEBUG battery fixture 95%; it is Simulator proof only. The widget used English, following the Simulator system language rather than launch-only main-app language arguments.

## Remaining acceptance gates

1. Select a development team for both targets, sign/install on a physical iPhone. Test actual battery/charging, Low Power Mode, thermal state, Wi-Fi/cellular/offline transitions, CPU/memory and network accuracy.
2. Physical Live Activity: background wait, stale timestamp, resume, stop, system/user dismissal, disabled permission and restoration. Expanded/minimal Island and all four widget languages require rendered checks. Continuous foreground-style 30 fps animation and continuous background sampling are constrained by ActivityKit; the app displays the last sample with paused/stale state.
3. Physical animation performance, memory/energy and thermal behavior. Simulator recordings do not establish sustained frame pacing or battery cost.
4. Small-phone, iPad and rotation layout; large accessibility text, VoiceOver focus/order and Reduce Motion runtime checks. Accessibility labels and reduced-motion branches are implemented, but a full accessibility audit is not complete.

No upload, TestFlight release, App Store submission or device installation was performed.

## Thermometer follow-up — 2026-10-11

Added a qualitative thermometer below Hardware CPU/memory gauges, with animated liquid transitions and green/yellow/orange/red system thermal states. Unknown leaves the app tube empty; Widget shows a neutral question mark. Reduce Motion suppresses transitions. No Celsius sensor reading is invented: ProcessInfo exposes only categories. Dashboard/Details explain this in all four languages.

Live Activity payload includes optional thermalStateRawValue and decodes older payloads without the field. Lock Screen and expanded Island include the thermal indicator. Native Hant/Japanese nominal-state screenshots (`thermometer-zh-Hant.png`, `thermometer-ja.png`) were inspected; Japanese scope text fits in two lines. Lock Screen nominal state was observed (`thermometer-live-lockscreen.png`); that capture predates the final English wording change from Nominal to Normal. Final source unifies Normal/Warm/Hot/Critical with the app. Expanded Island implementation is compiled but not newly rendered.

Seven XCTest tests pass, including legacy missing-field decoding and all five state roundtrips (`thermal-tests.log`). Final Debug app/extension build passes (`thermal-debug-build.log`); Release signing-disabled build passes (`thermal-release-build.log`). Translation checks pass: 118 app keys and 15 widget keys for each of four languages.

Real device category transitions, all-state rendering, small phone, Reduce Motion and VoiceOver runtime remain unverified. Simulator nominal state is not physical temperature proof.

## Three-instrument review — 2026-10-11

Battery charge status is now explicit: Charging, Full, Unplugged, or Unavailable, using UIDevice's reported state rather than inferring Full from the percentage. A state icon and timestamp sit under the original green battery animation. The unplugged symbol was corrected to battery.100percent and confirmed rendered.

Temperature and storage share the original Hardware section's value–instrument–label alignment: 30-point light values, 88-point instruments and compact labels. The thermometer is a bare instrument on black, without the former gray card; its scope explanation remains in Details. Storage reuses the yellow source half-dial for used percentage, with available/total byte values below. Invalid capacities show unavailable and used bytes are clamped to the valid capacity range. Thermal data remains categorical, with no Celsius value invented. Original battery frames and timing are unchanged.

Passed final Debug app/extension build (instruments-debug-build.log), unsigned Release iOS build (instruments-release-build.log), and nine XCTest tests with zero failures (instruments-tests.log). App localization parity is 120 keys per language; Widget parity is 19 keys per language. Binary inspection confirmed all preview flags are excluded from Release (instruments-release-fixture-check.txt).

Six rendered dashboard captures were visually inspected: instruments-charging-normal-en.png, instruments-full-warm-en.png, instruments-unplugged-hot-en.png, instruments-charging-critical-ja.png, instruments-unknown-zh-Hant.png, and instruments-charging-normal-zh-Hans.png. Together they cover all four languages, four battery states, and five thermal states including unavailable. Values, labels and the two Hardware instrument columns fit. These captures explicitly display the DEBUG demo banner. Battery/thermal values are fixtures; storage remains the Simulator host volume (approximately 1.81 TB), not a physical iPhone reading. Missing-storage behavior is source/test verified, not a rendered fixture.

Lock Screen Live Activity displayed 68%, Charging, and Normal thermal state with the expected green/yellow/cyan instruments and paused timestamp after backgrounding (instruments-live-charging-lockscreen.png). This is Simulator fixture proof. The new full/unknown/unplugged Live Activity payload states are tested; expanded Island and all translated widget states still require rendered checks. Storage stays in the app and is not included in the ActivityKit payload.

Physical battery/charging/storage/thermal accuracy, small-phone/iPad layouts, expanded Island, accessibility and animation energy/frame pacing remain acceptance gates listed above.

## Home Screen widgets — 2026-10-11

Implemented WidgetKit small, medium and large families alongside the existing Live Activity. The black background, outlined double-wave battery, qualitative thermometer and yellow half dial follow Resource styling. Widgets use static instruments rather than the foreground app animation loop. Small shows battery/charging/thermal; medium and large add storage, with the same byte formatting as the dashboard. All families show capture time.

Refresh: one-shot extension-safe battery/thermal/disk sampling; requested timeline reload after 30 minutes. A future entry at 60 minutes preserves the original values/time and marks stale, including advance rendering. App foreground and explicit Refresh now request reloads; the two-second sampling timer does not. Actual timing remains controlled by iOS.

Validation:

- Final integrated Debug build/run and unsigned generic-iOS Release build passed (`home-widget-debug-build.log`, `home-widget-release-build.log`).
- 19 dynamic assertions against the extracted actual Swift entry model plus 3 timeline-policy source checks passed (`home-widget-model.txt`). Covers stale boundary, unchanged timestamp/data, early rendering, invalid storage, unavailable battery and preview isolation. Existing XCTest suite was not rerun for this widget follow-up.
- Four-language source parity: 120 app keys and 31 widget keys per language (`home-widget-localization.txt`).
- Installed all three families on iPhone 17 / iOS 27 Simulator, visually checked English labels, unavailable battery, Normal thermal state and actual host volume values. Gallery preview is explicitly sample data. Corrected large charging-caption containment and shortened refresh hint. Final medium/large capture: `home-widget-medium-large-final-en.png`; earlier small, medium, large and large-gallery captures are retained.
- Tapping the medium widget opened the native dashboard. Capture timestamps subsequently advanced from 10:55 to 11:00 after foreground/reload. This proves an observed reload, not a fixed scheduled interval.
- Extension privacy manifest uses required filename `PrivacyInfo.xcprivacy`, with disk-space reason 85F4.1, no tracking or collected data.

Open acceptance: physical iPhone measurement accuracy and OS refresh budget/lifecycle; four-language rendered widget layouts; VoiceOver; actual delayed one-hour stale presentation (model verified, no hour-long runtime wait). Simulator disk values represent the host volume. iOS exposes thermal categories, not a Celsius temperature reading.

## Dashboard spacing revision — 2026-10-11

The user's original panel screenshot showed substantially more space between headings, values, instruments and captions. Dashboard section gaps increase 26→36 pt, hardware/network heading spacing 15→28 pt, hardware column gaps 16→36 pt, and instrument stack gaps 2→18 pt. Half-dial artwork and network rings have 18 pt horizontal inset; hardware value/label alignment stays shared with the thermal/storage row. Battery instrument area increases 164→226 pt. Storage footer gap increases 2→12 pt.

Debug app/extension build and launch passed (`dashboard-spacing-debug-build.log`). Actual English dashboard was visually inspected at the top and after scrolling on iPhone 17 / iOS 27 Simulator; titles, both hardware rows, storage footer and Network content are separated without overlap. Saved `dashboard-spacing-top-en.png` and `dashboard-spacing-lower-en.png`. No telemetry code, widget code or animation logic changed. No new automated tests were added for this spacing-only change. Smaller phone/iPad/translated and accessibility-size rendering remain unverified for this revision.

## Independent Temperature / Storage sections — 2026-10-11

User requested the original title-dot-line motif and separate rows with dedicated colors. SectionHeading now renders a 3 pt colored dot joined to its 1 pt line. Temperature is its own orange section with a centered thermometer; Storage is its own purple section with a centered half dial and capacity footer. Original CPU/Memory remain in yellow Hardware. Compact order: Battery, Hardware, Temperature, Storage, Network, Live Activity. Regular-width layout also registers the two independent sections. Four app languages include new section labels (122 matching keys).

Debug app/extension build and launch passed (`Validation/independent-sections-debug-build.log`). Visually checked orange Temperature with Normal/thermometer/caption, purple Storage with value/dial/footer, and title-dot-line separators on iPhone 17 Simulator. Storage capture: `Validation/independent-storage-en.png`. Thermal warning categories still retain distinct fill colors; orange is the normal temperature identity. Translated rendered layouts, iPad and accessibility text remain open; no new automated tests for this layout-only change.


## System CPU / System RAM — 2026-10-11

Hardware and History now use distinct optional system measurements. Details retains separately named app CPU and app memory footprint. ActivityKit content and Live Activity labels now use system fields, with unavailable values for legacy payloads rather than app-value fallback. The latest spacious dashboard and orange Temperature / purple Storage sections are preserved.

CPU uses public Darwin HOST_CPU_LOAD_INFO aggregate tick deltas: (user + system + nice) / total, with 100% representing all cores. Sampling handles counter wrap, cached samples, API failures and lifecycle rebaseline. RAM estimates used physical capacity minus reported free pages times host page size; includes occupied caches and system allocations. Free pages already include speculative pages. Host send rights are released after every sample. Unsupported/invalid readings stay unavailable. Simulator readings describe the Mac host.

Validation:

- Final Debug app/extension build and launch passed (`system-telemetry-debug-build.log`).
- Final unsigned generic-iOS Release app/extension build passed (`system-telemetry-release-build.log`).
- 15 XCTest tests passed, zero failures/skips (`system-telemetry-tests.log`): CPU aggregation/wrap/cache/discontinuity/reset, RAM arithmetic/invalid input/overflow, separate fields, CSV scope, lifecycle and new/legacy Live Activity payloads.
- All four app languages have 127 matching keys; widget languages have 33 matching keys. Literal localization coverage passes (`system-telemetry-localizations.txt`). Fixed the small Home widget accessible battery label to use its existing localized key.
- Actual English Dashboard visually inspected on iPhone 17 / iOS 27 Simulator (`system-telemetry-dashboard-en.png`): System CPU, System RAM, all-core/cache estimate note and Simulator host note fit. Observed roughly 78% CPU and 63.74 GB RAM are Mac-host readings, not iPhone measurements.
- Live Activity activation showed active status in the app. Attempted lock-screen capture (`system-telemetry-lockscreen-en.png`) did not display the activity; it is not rendering proof. Shared Device Hub selection was repeatedly changed by another task, so further UI interaction stopped to avoid interfering with that task.

Open acceptance: physical iPhone host API availability/accuracy and lifecycle; updated Live Activity lock-screen/Island rendering; History/Details rendered layouts and four-language rendered labels. Home Screen widgets retain battery/thermal/storage snapshots and their existing OS-controlled refresh policy.


## Dashboard value animations — 2026-10-11

Main-app HalfGauge needles use scoped 0.72-second ease-in-out rotation interpolation on the original Resource pin image. CPU, RAM and Storage values use SwiftUI numericText content transitions; NetworkRing values and battery percentage use the same duration and monospaced digits. Animation modifiers are attached only to the changing number/needle, preserving the existing spacing. Unavailable gauge values keep the needle hidden and do not sweep to an invented zero. Reduce Motion disables the explicit value animations. Existing Resource battery animation and thermometer motion are preserved.

Debug app/extension build and launch passed (`dashboard-motion-build.log`). Captured ten seconds of real Simulator foreground sampling (`dashboard-motion.mp4`); inspected extracted frames showing RAM digit transitions and CPU 64% to 62% with intermediate needle positions (`dashboard-motion-detail.png`, `dashboard-motion-needle.png`). Simulator host measurements only. No new model tests for this view-only change; no telemetry or refresh-policy changes. Battery/Storage/Network transition paths share the same modifiers, but changing those values and Reduce Motion behavior were source-reviewed rather than separately exercised. Widget/Live Activity views remain unchanged in this revision.


## Number jump revision — 2026-10-11

Replaced main-app numeric rolling transitions with a single small hop on displayed-value changes: 4 pt rise over 0.12 s and spring settle over 0.38 s. Applies to HalfGauge CPU/RAM/Storage, network values and battery percentage. Stable text identity and offset preserve layout, while Reduce Motion forces zero displacement. Needle smooth rotation remains unchanged. Final Debug build/run passed with no warnings (`dashboard-number-jump-build.log`). Recorded six seconds of real foreground Simulator updates (`dashboard-number-jump.mp4`); frame inspection shows changing CPU/RAM text displaced during the hop and back on its original baseline. Widget/Live Activity unchanged.


## Thermal color and fill revision — 2026-10-11

Normal/nominal now uses green text and thermometer fill, Fair yellow, Serious orange, Critical red. Decorative tube proportions are 50%, 70%, 85%, and 100% (revised 2026-10-13); they do not represent measured Celsius values. Main-app fill keeps stable geometry and animates from zero on appearance and between states over 0.85 s ease-in-out, respecting Reduce Motion. Temperature section identity remains orange. Home widget thermometer proportions match; Live Activity already uses the same four status colors. Widget updates remain controlled by WidgetKit.

Final Debug app/extension build and launch passed, no warnings (`thermal-fill-build.log`). Visually inspected Critical red full tube and Normal green low tube in explicit DEBUG design fixtures (`thermal-critical-fill.png`, `thermal-normal-fill.png`). Normal was observed partially filled immediately after scrolling into view, establishing visible entry fill progression. Critical capture predates the final status-text color change; full tube geometry is unchanged. Fair/Serious and state-to-state/Reduce Motion paths source-reviewed; physical thermal changes remain unverified. No telemetry or actual-temperature conversion was introduced.


## Battery status right column — 2026-10-11

Moved charging-state icon/text and capture time from the separate battery footer into a right-aligned column beside the battery percentage, matching the reference image's right text area. Kept Resource battery waves, number-hop animation, low-power indication and section spacing. All battery state labels remain localized; no estimated Idle/Web/Video times were invented. Final Debug build/run passed without warnings (`battery-status-right-build.log`). Visually inspected the explicit Charging design fixture on iPhone 17 Simulator (`battery-status-right.png`); icon, label, timestamp and percentage fit. Smaller phones and translated rendered layouts remain unverified for this revision.


## Configurable Live Activity and widgets — 2026-10-13

Users can choose 1–3 Live Activity metrics in Settings → Live Activity data: Battery, System CPU, System RAM, Network, Temperature, Storage. Selected rows show their display-order number; the last selected item cannot be removed and a fourth cannot be added. JSON preferences persist on device. Existing activities refresh their layout immediately, bypassing the normal telemetry-write throttle without implying a new measurement. Lock Screen/expanded Island show the selected items only; compact/minimal Island uses the first item. Legacy payloads fall back to Battery/CPU/Network. Storage fields are included only when storage is selected.

Each Home Screen widget uses AppIntentConfiguration with First/Second/Third metric parameters; the first is required, optional slots allow None, and duplicate selections collapse. Supported options are Battery, Temperature, Storage, System RAM. Small shows the first item; medium/large up to three. RAM sampling is a one-shot public-host estimate only when selected; no CPU interval sampler or interface rate is offered in the widget. Fresh and stale entries preserve selections and original RAM/capture time. The 30-minute refresh request and 60-minute stale boundary remain unchanged.

Validation:

- Final Debug app/extension build/run and unsigned generic-iOS Release build passed with no warnings (`display-configuration-debug-build.log`, `display-configuration-release-build.log`).
- 23 XCTest tests passed, zero failures/skips (`display-configuration-tests.log`). Eight new tests cover persistent JSON settings, ordered/deduplicated/bounded selections, malformed/legacy fallback, new content, unavailable system readings and conditional storage exclusion. Existing tests now supply explicit metrics to avoid depending on manual QA preferences.
- Real Widget entry source is extracted by `Scripts/verify-home-widget-model.py`: 23 Swift model assertions and 3 timeline-policy checks passed (`display-configuration-widget-model.txt`). New checks prove stale fallback retains metric order and original RAM/capture data.
- Four app locales have 137 matching keys; four widget locales have 47 matching keys. `Scripts/verify-localizations.py` passed literal UI coverage. During rendering, fixed a dynamically interpolated metric key that initially displayed raw keys; final selection labels are localized.
- Actual English Live Activity selector tested on iPhone 17 / iOS 27 Simulator: one-item minimum and three-item maximum disabled appropriate rows; changed selection to RAM/Temperature/Storage, with visible order numbers (`live-data-selection-en.png`). Preferences persisted across app reinstall/launch.
- Lock Screen showed selected RAM/Temperature/Storage and paused capture time (`live-data-custom-lockscreen-en.png`). Later started an activity, removed RAM while it was active, and observed Temperature/Storage without restarting (`live-data-updated-two-items-en.png`). Compact Island was observed displaying the first selected RAM value. Expanded Island remains source/build verified only.
- Actual system Edit Widget opened with localized three-slot controls (`widget-data-configuration-en.png`), changed First metric to RAM, and rendered it. Configuration survived app reinstall. Actual small, medium and large RAM/Temperature/Storage layouts fit (`widget-data-small-ram-en.png`, `widget-data-medium-en.png`, `widget-data-large-en.png`). Medium retains available/total storage captions.

Open acceptance: physical-device accuracy, OS refresh budget and lifecycle; translated rendered configurations/layouts, accessibility interaction, expanded Island and all metric combinations. Simulator RAM and storage are Mac-host measurements. No new network service, App Group or watchOS target is introduced.


## Live Activity storage caption — 2026-10-13

Removed visible Pause labels/icons from the Lock Screen and Dynamic Island. Compact trailing now shows purple storage-used percentage; snapshot captions include the same percentage and original capture time. Storage fraction is always included; detailed storage byte values remain conditional on selection. Legacy/unavailable fractions show an em dash. Sampling lifecycle is unchanged: foreground writes about every 10 seconds, final snapshot at background transition, no scheduled periodic background refresh. Reopening the app resumes updates.

Debug build/run passed without warnings; all 23 XCTest tests passed, including revised unconditional-fraction/conditional-byte payload assertions. Logs: `live-storage-caption-build.log`, `live-storage-caption-tests.log`. Rendered layout and physical-device lifecycle were not rechecked for this narrow revision.


## Thermal fill revision — 2026-10-13

App, Home widget and Live Activity map nominal/fair/serious/critical to 50/70/85/100 percent. Existing colors and app fill animation are preserved. Debug app/extension build and Simulator launch passed without warnings (`thermal-fill-levels-build.log`). All three switches were source-checked; no new rendered animation capture was performed.


## Modular architecture — 2026-10-13

Extracted `Packages/MonitorKit` with compile-time MonitorDomain, MonitorTelemetry and MonitorActivity modules. App and extension link package products; shared Swift files no longer compile independently in both targets. Domain models own no view or scene lifecycle. Telemetry internals remain internal and tests use @testable import. ActivityKit snapshot mapping stays in the shared contract. App lifecycle services and feature/component/design-system folders are separated. Widget presentation is split into bounded views, drawings, formatting and chrome files; existing view source is preserved apart from required access/import changes.

Validation: Debug app/extension build and Simulator launch passed without warnings; unsigned generic-iOS Release build passed without warnings; all 23 XCTest tests passed. Four locale sets match and all 1,173 original battery frames match bundled copies. Home-widget model: 23 Swift assertions and 3 timeline-policy checks pass. Saved local logs: `modular-debug-build.log`, `modular-release-build.log`, `modular-tests.log`. Actual English Dashboard, configured Temperature/Storage Live Activity and default medium Home Widget were visually inspected on iPhone 17 / iOS 27 Simulator (`modular-dashboard-en.png`, `modular-live-activity-en.png`, `modular-home-widget-en.png`). Live Activity starts through the new package contract, shows storage caption and capture time. Physical-device and all-locale rendered acceptance remain open.

Git publication preserves the existing remote MIT license and initial main commit. SSH credentials already present on the host were used; new GitHub CLI OAuth access was not granted. Build products, raw logs, user state and authoring autosaves are ignored. Original artwork remains included.
