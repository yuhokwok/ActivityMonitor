# Activity Monitor — implementation and acceptance plan

## Scope and ownership

Native iPhone/iPad app, bundle identifier `com.invivo.ios.Activity-Monitor`, with English (`en`), Traditional Chinese (`zh-Hant`), Simplified Chinese (`zh-Hans`), and Japanese (`ja`). No watchOS app or watchOS target. Watch-sized materials in Resource are visual references only. The original Resource artwork and animation are the design contract; modern safe areas and readable localized text adapt the layout.

| Owner | Deliverable |
| --- | --- |
| Sol | Resource inspection, design direction, actionable plan and acceptance gates (this file) |
| Luna | Native dashboard, reusable animated instruments, details/settings, accessibility and localization |
| Astra | Device telemetry, sample lifecycle, truthful data scope, Live Activity attributes/controller/extension |
| Root | Project/target integration, build, simulator interaction and rendered QA, final status |

Checkboxes below describe acceptance, not claims of completed implementation. Resource inspection is complete; implementation and runtime gates remain open until evidence is recorded.

## Inspected source evidence

- [x] Viewed `Resource/UI_set_preview.png` (2684 × 1335). The left-hand panel is the phone design; the middle shows icon/watch variants and the right shows a historical Today extension. These extra surfaces do not authorize a watch target.
- [x] Viewed `Resource/Screen Shot 2015-05-26 at 6.47.40 pm.png`, confirming the large, light-weight battery-time typography.
- [x] Inspected `Resource/glance_animation.mov`: 312 × 390, 30 fps, 5.033333 seconds. Sampled at 0.2-second intervals through the rise and at 1-second intervals through the remainder. The battery starts empty, rises around the first second, then maintains two offset moving liquid contours. Its sample `00%` text is mock artwork, not a valid default measurement.
- [x] Checked phone assets: battery frame `@3x` 231 × 418 px; yellow half dashboard 374 × 180 px; yellow pin 12 × 138 px; blue full dashboard with background 378 × 358 px; high battery front wave 1325 × 578 px. Preserve aspect ratios and use the existing assets where practical.
- [x] Confirmed preview zip repeats the same movie and image. Do not bundle duplicate archive/PSD/AE project files into the app.
- [x] Verified bundled original animation frames using `Scripts/verify-resources.py`: all 1,173 SHA-256 comparisons match. Each low/medium/high band includes its 31-frame FloatUp entrance and 360-frame continuous loop, at 30 fps (`Validation/resource-integrity.txt`).

## Resource fidelity requirements

| Element | Required appearance and behavior | Acceptance |
| --- | --- | --- |
| Overall | True black instrument field, white primary values, compact section grouping; avoid filling the dashboard with generic opaque cards. Title/header may use a restrained charcoal strip like the source. | Black is visibly dominant in normal display. The three source sections are recognizable immediately. |
| Section headings | Battery in vivid green; Hardware in yellow; Network in cyan. Each heading has a fine horizontal rule beginning just after its label and continuing to the trailing edge. | Colors, line weight, heading hierarchy and spacing match the source at normal text size. |
| Battery hero | White outlined rounded upright battery with small white terminal, large light-weight percentage alongside it. Front and back liquid surfaces have differing phase/amplitude and a darker back layer. | Frame and liquid are aligned, liquid clips inside the battery, 0/20/50/80/100% remain readable, and unknown never renders a fabricated percentage. |
| Battery liquid | Preserve the exact original exported animation using the source PNG frames: a 31-frame FloatUp entrance followed by its 360-frame continuous loop at 30 fps. Root selected original-frame playback to honor the requested animation fidelity. Decode only the currently needed frame with a bounded cache. Color bands use source green/high, orange/medium, red/low assets; the numeric percentage remains the precise measurement. | Record a short screen video. Check the entrance-to-loop boundary and continuous loop for jumps; band changes use the corresponding original sequence. Unknown shows an empty/unavailable instrument. |
| Hardware | Two yellow semicircular instruments, small ticks, end dots, an upright needle pivot and subdued yellow interior; large values above and concise labels below. | Same instrument grammar as preview; needle positions express the actual normalized quantity with no NaN or out-of-range rotation. |
| Network | Cyan full circular rings with dots at left/right, stacked upload/download values and arrows; companion ring shows received plus sent interface counters. | Round at every size, typography stays inside, units are legible, and interface-counter scope is visible. |
| New phone status rows | Integrate battery charging, Low Power Mode, thermal state, device/OS, RAM capacity and storage below the matching source section. Use source accents and small supporting labels. | Added functions do not displace the three source instruments or change them into unrelated card designs. |
| iPad/landscape | Keep source instruments proportional; use a centered wider layout or columns where space allows. | No stretched circles/battery frames; every section and action remains accessible. |
| Reduced Motion | Replace continuous waves/rise with a stable liquid level and use immediate/gentle value changes. | Toggling system Reduce Motion removes ongoing decorative motion. |
| VoiceOver | Combine each instrument's name, value, unit, scope and availability into a meaningful reading. | Decorative ticks/waves do not create dozens of focus stops; action names are localized. |

Use the source's relative hierarchy: the battery is the opening hero, followed by two equal-width hardware instruments, then two equal-width network instruments. A scroll view is acceptable on smaller phones and with larger text. Do not reproduce the obsolete status bar or the historical Today/Notifications host UI.

## Functional decisions and truthful metric scope

| Feature | Intended implementation and label | Failure/limitation behavior |
| --- | --- | --- |
| Battery | `UIDevice` battery monitoring; charge percent and unknown/unplugged/charging/full states. | Battery level `-1` is unavailable. Simulator should say unavailable or explicitly identify simulation; no plausible fabricated battery reading. [Apple batteryLevel](https://developer.apple.com/documentation/uikit/uidevice/batterylevel) |
| Power and thermal | `ProcessInfo.isLowPowerModeEnabled` and `thermalState`, observing changes. | Thermal is categorical (nominal/fair/serious/critical), not a fabricated temperature in °C. Reduce decorative update cost when power/thermal state warrants it. [Low Power Mode](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled), [thermal state](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property) |
| CPU | Dashboard/History/Live Activity use **System CPU**, derived from non-idle aggregate `host_statistics(HOST_CPU_LOAD_INFO)` tick deltas, 0–100%; 100% means all logical cores combined. Details retains explicit **App CPU**, where 100% means one core. | First/baseline, failed, reset or invalid host samples are unavailable. Public host statistics can be cached/rate-limited; never substitute app-process CPU. Simulator host statistics describe the Mac. [Apple XNU host statistics](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/host.c) |
| Memory | Dashboard/History/Live Activity use **System RAM used (estimate)**: `physicalMemory − free_count × pageSize` from `host_statistics64(HOST_VM_INFO64)`. The gauge denominator is physical RAM. Details retains explicit app footprint and separate physical capacity. | `free_count` already includes speculative pages; do not subtract them twice. Used estimate includes non-free cache/reclaimable allocations, not just app footprints or memory pressure. Missing/invalid samples stay unavailable. Simulator values are Mac-host measurements. [host_statistics64](https://developer.apple.com/documentation/kernel/1502863-host_statistics64), [physical memory](https://developer.apple.com/documentation/foundation/processinfo/physicalmemory) |
| Storage | Used/free/total local volume values presented to the user. | Include `PrivacyInfo.xcprivacy` disk-space reason **85F4.1** for display; **E174.1** describes write-space checks and is not a substitute for this display use. [Required reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype) |
| Network path | `NWPathMonitor` connection state, Wi-Fi/cellular/wired/other, expensive and constrained status. | Path availability does not prove Internet reachability. No SSID/location permission merely to show path type. [NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor) |
| Transfer rate | If interface counters are available, compute nonnegative deltas over measured elapsed time and describe them as observed interface transfer. | Counters are not an ISP speed test or guaranteed all-app meter. Rebaseline on counter reset/interface change; avoid spikes after suspension. Distinguish kb/s from KB/s. |
| Transfer totals | Root selected received plus sent raw interface counters, with explicit interface scope; these are not a session accumulation feature and have no invented billing period. | Never present counters as monthly cellular billing usage or since-launch totals. Their lifetime/reset follows the operating system/interface. The historical preview's billing date is not evidence of that capability. |
| Battery time estimates | Add only if based on a clearly explained measured trend with adequate observations. | The source's Idle/Web/Video `4:50/6:45/2:30` values are mock data. If no reliable estimator exists, replace those labels with real battery state/power/thermal facts. |
| Device facts | Device category/model identifier, OS version, processor count, RAM capacity. | Avoid serial/IMEI, battery health/cycle count, or full running-process promises that public app APIs do not provide. |

Do not add raw device uptime as a convenience status field. Apple's **35F9.1** reason permits elapsed calculations between in-app events/timers, not arbitrary uptime display. If monotonic time is used for sampling intervals, declare the correct reason for that calculation. [System boot-time reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

## Live Activity product and lifecycle

Use an explicit monitoring session with **Start Live Activity** and **Stop Live Activity**. Keep at most one session per app; restore/reconcile existing activities after relaunch. Show a clear unavailable/disabled explanation when authorization is off, and show a localized failure message if request fails.

The Lock Screen layout reuses black/green/yellow/cyan instruments in a compact form: battery percent/state as the main value, one hardware/system state, network connection and last-update timestamp. Dynamic Island compact/minimal presentations prioritize the battery/status symbol and one concise value. The expanded presentation can include the three section colors. Do not package full-size phone artwork into tiny presentations.

Data refresh is local while the app receives execution time. A Live Activity cannot independently sample/network and does not guarantee continuous background execution. Use `staleDate`, a visibly localized stale state, and last-update time. Throttle meaningful content updates rather than send each animation tick. Current Apple documentation specifies up to eight active hours, with a remaining Lock Screen lifetime up to four additional hours, and a combined 4 KB attributes/state budget. [ActivityKit constraints and lifecycle](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)

- [x] Main app has Live Activity support enabled and the WidgetKit extension builds/embeds with a distinct bundle identifier under the app identifier.
- [ ] Foreground Start creates exactly one session; double-tap is safe; duplicate existing activities reconcile.
- [x] Sampling changes update content; decorative liquid animation never drives ActivityKit writes.
- [ ] Disabled authorization and request failure show actionable localized feedback.
- [ ] Stop ends the session and resets the in-app state; user dismissal/system expiry is reflected after reconciliation.
- [ ] Background snapshot clearly transitions to stale when it stops receiving updates; returning to foreground refreshes it.
- [ ] Lock Screen, compact/minimal/expanded Dynamic Island remain readable in each localization.
- [x] No watchOS target is introduced. Any operating-system mirroring of a Live Activity is not a separately implemented watch app.

## Actionable implementation checklist

1. Project and shared contracts
   - [x] Create native app project with exact bundle ID, four localizations, iPhone/iPad layout and WidgetKit Live Activity extension.
   - [x] Define one telemetry snapshot model with availability, scope, units and sample timestamp; share only small Codable Live Activity state.
   - [x] Include the source phone artwork/icon in an asset catalog; omit source design projects and redundant archives from the product.
   - [x] Copy and checksum all 1,173 original sequence PNGs for native playback without alteration.
2. Telemetry and lifecycle
   - [x] Read battery, charging, low-power, thermal, physical RAM, storage and network path.
   - [x] Retain measured App CPU/App memory in Details with explicit scope and defensible normalization.
   - [ ] Complete the subsequent system CPU/RAM dashboard/History/Live Activity revision and its acceptance checks below.
   - [x] Sample foreground rates, rebaseline after resume/path changes, stop unnecessary work in background.
   - [x] Declare actual required-reason APIs in the correct target privacy manifests.
3. Native dashboard and details
   - [x] Implement source-shaped battery waves, yellow half gauges and cyan circles.
   - [x] Add phone status/details and describe measured interface counter scope.
   - [x] Implement Settings/about data scope, Live Activity controls, localization and Reduce Motion; add accessibility labels. Large-text and VoiceOver runtime acceptance remain open.
4. Live Activity
   - [x] Implement start/update/stop, authorization/error states, activity restoration and stale presentation.
   - [x] Implement Lock Screen and all Dynamic Island presentations with the source visual accents.
5. Integration and acceptance
   - [x] Build app and extension with current Xcode; verify embedded extension and configured bundle IDs/localizations.
   - [x] Run interaction and rendering checks below; record evidence and remaining physical-device gates.

Implementation checkboxes above indicate code completion, not full runtime acceptance. Simulator Start/Stop, Lock Screen and compact Dynamic Island were observed; disabled authorization, dismissal, all-language widget presentation and physical-device lifecycle remain open. See `Validation/REPORT.md`.

## Verification matrix

| Check | Evidence required | Gate |
| --- | --- | --- |
| Native build | Successful app + extension build, target membership and bundle-ID inspection. | Build only; does not prove telemetry correctness. |
| Phone layout | Simulator screenshots at a small phone and modern Dynamic Island phone; compare against the source section/color/instrument checklist. | Values/labels contained, no unintended truncation or stretched graphics. |
| iPad and rotation | Portrait/landscape screenshot and scroll/action interaction. | No frame distortion, unreachable controls or overlap. |
| Four languages | Render `en`, `zh-Hant`, `zh-Hans`, `ja`, including Settings/errors/Live Activity labels. | No missing raw localization keys; long labels fit. |
| Accessibility | Large accessibility text, VoiceOver focus order, Reduce Motion on/off. | Values and actions understandable; movement stops as requested. |
| Animated battery | Short simulator recording at representative charge levels and threshold transitions. | Two layers, initial rise, smooth ongoing phase, proper clipping. |
| Sampling math | Focused tests for unavailable readings, first sample, counter reset, long suspension and unit conversion if that math is present. | No invented zero/negative transfer/spike or invalid needle. |
| Real telemetry | Physical iPhone: charging cable change, Low Power Mode toggle, Wi-Fi/cellular/offline transitions, real memory/CPU sampling behavior. | Unverified until performed on hardware. |
| Live Activity | Physical iPhone: start, lock, background wait past stale date, return, stop, Settings-disabled and user-dismissed states. | Simulator/build is not proof of Lock Screen/background lifecycle. |
| Energy/performance | Physical iPhone observation of sampling/wave cost and thermal/power adaptation. | No continuous background polling claim without measured evidence. |

Acceptance reporting must distinguish source fidelity, simulator runtime proof, API/build proof and physical-device proof. Record exactly which gates passed and which remain open; never check a hardware gate solely because the product built.

## Thermal thermometer follow-up

The added thermometer is a qualitative device thermal-state instrument. `ProcessInfo.thermalState` reports nominal, fair, serious or critical; there is also an unavailable/unknown presentation. Its four liquid heights express the order of those states, not measured temperature, degree intervals or an inferred Celsius value. Keep the black source background and green/yellow/orange/red state accents. Do not show a numeric °C reading, temperature scale or fabricated sensor value.

Implementation checklist:

- [x] Add the thermometer to Hardware in the native dashboard and include its state/scope in Details.
- [x] Map the four known states to qualitative liquid levels/colors and localized names; unknown uses an empty tube and neutral bulb.
- [x] Provide English, Traditional Chinese, Simplified Chinese and Japanese labels explaining the thermal-state scope.
- [x] Suppress state-change animation under Reduce Motion and give VoiceOver a combined thermal label/value/scope hint (source review only).
- [x] Add an optional raw thermal-state value to shared ActivityKit content so previously encoded content without the field remains decodable; legacy decoding and all-state round-trip tests passed in Root's seven-test run.
- [x] Add the compact static thermal indicator to Live Activity with four localized states and a neutral question-mark fallback for missing or unfamiliar values; unknown does not show a fabricated liquid level.
- [x] Preserve the bounded scalar ActivityKit content and cover missing-field decoding plus known/unknown categories in the existing seven-test suite. ActivityKit accepted the updated nominal-state content in Root's runtime observation; no additional test expansion is required for this follow-up.
- [x] Build the updated app/extension in Debug and Release (Root verification).
- [x] Inspect the dashboard thermometer rendered in Traditional Chinese and Japanese; the Japanese scope label fits across two lines (Root observation).
- [x] Observe the updated thermal indicator on the Simulator Lock Screen (`Validation/thermometer-live-lockscreen.png`). The image predates the final English label change from Nominal to Normal; final source uses Normal/Warm/Hot/Critical like the app.
- [ ] Inspect Details and unknown/missing-state Live Activity rendering.

Acceptance checklist:

- [x] Render all four qualitative levels plus unknown in clearly marked design previews; no fake temperature numbers appear. The final bare-instrument screenshots below cover these states.
- [x] Inspect Japanese dashboard text for label wrapping; observed scope text fits across two lines.
- [ ] Inspect a small phone for liquid containment, label wrapping and unchanged source instrument proportions.
- [ ] Check Reduce Motion while transitioning states and VoiceOver's thermal reading order.
- [ ] Observe a real device's system thermal state and confirm the dashboard/Live Activity report the same category after refresh. A simulator/design preview does not establish hardware thermal accuracy.

The native source review found the four-state mapping, unavailable handling and reduced-motion branch present. Root initially verified Debug/Release builds, seven tests, Traditional Chinese/Japanese dashboard rendering and nominal-state Lock Screen rendering. The subsequent bare-instrument revision below adds all-five-state dashboard visual coverage. The remaining gates cover small-phone layout, Details/unknown Live Activity presentation, reduced-motion/VoiceOver behavior and physical-device accuracy. Expanded/minimal Island and all four widget languages remain separate rendered-acceptance gates.

## Charging, storage and thermometer alignment follow-up

Re-read the phone panel on the left of `Resource/UI_set_preview.png`. Its instrument layout is a black field with colored section dividers, large light white values above instruments, and small labels below. Replace the thermometer's charcoal rounded card with a bare instrument so the three new functions fit this original design language.

Design contract:

- Battery footer explicitly combines the measured charging state with a matching symbol and localized value. The states remain unknown, unplugged, charging and full from `UIDevice.batteryState`; do not infer full from a rounded `100%` percentage. Remove redundant charging-state text from the hero if needed. Any retained clock is clearly a sample timestamp, never an Idle/Web/Video time estimate.
- Hardware retains the original first row of yellow CPU and memory half dials. A second row uses two equal-width instruments: qualitative thermometer on the left and storage on the right. Align their value/instrument/label hierarchy with the row above; use no rounded cards behind them.
- Storage reuses the original yellow half dial and pin. Its large value is the used-capacity percentage, the pin represents used/total capacity, and compact supporting labels show available and total bytes. Root accepted this percentage presentation, consistent with the original CPU dial. Keep the source aspect ratio and subdued yellow interior.
- Thermometer retains a white/yellow outline against black and green/yellow/orange/red ordinal-state accents. Known states have qualitative liquid levels; unknown leaves it empty. Keep its localized scope explanation in Details, with the dashboard's concise thermal-state label below the instrument. No numeric Celsius value or degree scale.
- Storage remains a user-visible main-app/Details value. Existing CSV and ActivityKit payload omit storage; the display-only disk-space reason **85F4.1** remains applicable. No new external sharing or billing claims.

Implementation and source-review checklist:

- [x] Confirm existing core snapshot provides exact charging state plus used/available/total storage and bounded used-capacity fraction.
- [x] Add the explicit charging-status footer with four localized values/symbols and unavailable handling; ActivityKit also preserves the exact optional raw state while retaining the legacy powered-state Boolean.
- [x] Add source-style storage half dial and truthful percentage/available/total labels to the dashboard; invalid storage values remain unavailable.
- [x] Replace the thermometer card with a bare instrument in the second hardware row.
- [x] Review all three components together for four-language coverage, symbol/state correctness and unavailable behavior. Both second-row columns share value/instrument/label heights and flexible equal-width frames; the storage footer follows its label.
- [x] Build app and extension after the integrated UI changes in Debug/Release; Root reported nine passing tests and localization key parity (120 app keys, 19 widget keys per language).

Runtime acceptance:

- [x] Inspect final rendering of charging status, thermometer and storage together across all four main-app languages; compare directly to the Resource phone panel. Values and labels align across the two hardware rows, and the new instruments have no rounded-card background.
- [x] Observe all four charging states and all five thermal presentations, including unknown battery/thermal empty instruments, in marked design previews. Root also fixed the unplugged SF Symbol to `battery.100percent`, rebuilt and re-captured that case.
- [x] Review unavailable storage handling in source and passing invalid-capacity tests: missing/negative values do not produce a false zero percentage or needle.
- [ ] Render an unavailable-storage case; no storage fixture or hardware failure case was used in this follow-up.
- [ ] Observe real charging/unplugged/full transitions and device storage values on a physical phone; Simulator host capacities are not iPhone capacity proof.
- [ ] Preserve the existing open small-phone, iPad/rotation, Reduce Motion, VoiceOver and physical thermal-state gates.

Root owns build/runtime validation. Sol's follow-up review is read-only for UI/Core/Shared/Widget; only this planning file is changed by Sol.

Final dashboard evidence: `instruments-charging-normal-en.png`, `instruments-full-warm-en.png`, `instruments-unplugged-hot-en.png`, `instruments-charging-critical-ja.png`, `instruments-unknown-zh-Hant.png`, and `instruments-charging-normal-zh-Hans.png` under `Validation`. Root inspected all six; Sol viewed the set and re-opened the unknown Traditional Chinese image at original resolution to confirm complete text, empty thermal tube and unavailable battery. Capacity values are actual Simulator-host measurements, not physical iPhone values.

- [x] Observe the updated Simulator Lock Screen Live Activity with exact Charging status, 68% DEBUG battery fixture and Normal thermal state; all labels fit and the paused timestamp remains visible after backgrounding (`Validation/instruments-live-charging-lockscreen.png`). Storage is omitted from this payload.
- [ ] Render the updated charging presentation in expanded/minimal Dynamic Island and all four widget languages.
- [ ] Verify real charging/thermal categories and Live Activity background lifecycle on a physical device. The saved Lock Screen image is Simulator proof only.

## Home Screen widget follow-up

Add a native WidgetKit Home Screen widget in small, medium and large families. Preserve the Resource black field, white battery outline/double static wave, yellow half dial and concise labels. Small shows battery percentage, exact charging state and qualitative thermal state; medium and large also show display-only storage. Retain an explicit localized last-update timestamp in every family.

WidgetKit controls refresh timing. Request a fresh timeline after approximately 30 minutes, and include a future entry after 60 minutes that marks the same captured values stale if the system delays refresh. The future entry must preserve the original capture timestamp. Do not use the app's two-second timer, promise continuous real-time sampling, or report the widget extension's CPU/memory as the main app's measurements. Storage remains on-device display only, absent from CSV and ActivityKit payload.

The subsequent system CPU/RAM request does not expand Home Screen widgets: they continue to sample battery, thermal state and storage only. Do not add a two-sample CPU polling loop to the widget provider.

Implementation/source review:

- [x] Register the Home Screen widget alongside the existing Live Activity in the extension bundle and declare small/medium/large families (source review; final bundle build remains separate).
- [x] Review one-shot data capture, 30-minute refresh request, 60-minute stale entry and unchanged original timestamp; no repeating timer/background polling is introduced. Future-entry date also marks stale during advance rendering.
- [x] Confirm unavailable battery/thermal/storage values remain unavailable, with exact charging-state handling and no invented Celsius reading. Production entries sample only device battery/thermal/storage; gallery fixtures are explicitly preview-only.
- [x] Review Resource visual grammar and three family source layouts: black background, white outlined double-wave battery, qualitative thermal column and yellow storage half dial. All four widget localizations have 31 matching keys and no missing literal widget key. Medium explicitly labels the update time; unknown charging is neutral gray; compact thermal geometry fits its allocated frame.
- [ ] Verify VoiceOver readings and final instrument containment in rendered families; the small battery percentage needs an explicit accessible battery label.
- [x] Verify the display-only disk-space privacy reason **85F4.1** in the extension and app-triggered WidgetKit reload behavior without a two-second reload loop (source/project registration review).
- [x] Build app/extension in Debug and Release; 19 source-derived Swift model assertions and 3 timeline-policy checks pass.

Rendered/runtime acceptance:

- [x] Add actual small, medium and large widgets to the Simulator Home Screen; English values, labels, timestamp and instruments fit. Final storage formatting matches the dashboard.
- [ ] Render all four languages and verify long labels fit; inspect unavailable/stale presentation with the original last-update timestamp.
- [x] Tap the medium widget to open the native dashboard. Observe timestamps advance after app foreground/reload; scheduled 30-minute refresh timing is not runtime-verified.
- [ ] Verify physical-device battery/thermal/storage readings and system-controlled refresh lifecycle. Simulator/build evidence does not establish hardware accuracy or refresh guarantees.

Root owns runtime evidence. Sol reviewed provider/view/integration source read-only: app reloads occur when foreground sampling starts or the user explicitly refreshes, not from the two-second sampling loop. Medium timestamp labeling, neutral unknown charging style and compact thermal geometry were corrected after review; four-language key coverage passed. Final rendering and VoiceOver evidence remain pending. Astra reported extension-safe typechecking and focused provider assertions covering the 60-minute threshold, unchanged stale timestamp, early rendering, unavailable battery, invalid storage and preview behavior; Root's integrated build/runtime evidence is pending.

Root final evidence: `Validation/home-widget-medium-large-final-en.png` shows actual medium/large readings and the aligned storage units; small and gallery captures are also saved. A localized battery accessibility label was added, but VoiceOver interaction remains open. Final Debug/Release logs and `home-widget-model.txt` are saved. Four-language key parity passes (31 widget keys each); translated rendered layouts and physical-device lifecycle remain open. The extension privacy manifest is bundled under the required name `PrivacyInfo.xcprivacy`.

## Dashboard spacing revision — 2026-10-11

- [x] Use the user's original panel screenshot as the spacing reference.
- [x] Increase section separation to 36 pt, heading-to-content spacing to 28 pt and battery instrument region to 226 pt.
- [x] Increase value/instrument/label spacing to 18 pt; use 36 pt between hardware columns and inset instrument artwork for breathing room. Match the thermal/storage row's value and label rhythm.
- [x] Inset network rings and increase header/footer spacing; keep all sections vertically scrollable.
- [x] Debug build/run passed; visually inspected the top and scrolled lower dashboard on iPhone 17 Simulator. Captures: `Validation/dashboard-spacing-top-en.png`, `Validation/dashboard-spacing-lower-en.png`.

This revision changes main-app dashboard layout only. Widget and Live Activity compact layouts have their own size constraints. Smaller phones, iPad, translated rendered layouts and large accessibility text remain acceptance gates.

## Independent Temperature / Storage sections — 2026-10-11

User requested the original title-dot-line motif and separate rows with dedicated colors. SectionHeading now renders a 3 pt colored dot joined to its 1 pt line. Temperature is its own orange section with a centered thermometer; Storage is its own purple section with a centered half dial and capacity footer. Original CPU/Memory remain in yellow Hardware. Compact order: Battery, Hardware, Temperature, Storage, Network, Live Activity. Regular-width layout also registers the two independent sections. Four app languages include new section labels (122 matching keys).

Debug app/extension build and launch passed (`Validation/independent-sections-debug-build.log`). Visually checked orange Temperature with Normal/thermometer/caption, purple Storage with value/dial/footer, and title-dot-line separators on iPhone 17 Simulator. Storage capture: `Validation/independent-storage-en.png`. Thermal warning categories still retain distinct fill colors; orange is the normal temperature identity. Translated rendered layouts, iPad and accessibility text remain open; no new automated tests for this layout-only change.

## System CPU / System RAM revision — 2026-10-11

User now requires system-wide CPU and RAM in Hardware and History. This supersedes the earlier app-only dashboard scope; previous screenshots/test reports establish only that earlier implementation. Keep the two original yellow half dials and the latest independent Temperature/Storage sections. Details retains separate app-process CPU/footprint values, while Live Activity gains distinct optional system fields.

CPU is the aggregate non-idle tick delta divided by the total tick delta across all logical cores, bounded to 0–100%. RAM used is an estimate of physical capacity minus reported free pages times the host page size. Apple's XNU implementation includes speculative pages in `free_count`; subtracting `speculative_count` again would understate usage. Non-free cache/reclaimable allocations remain included, so this is not a memory-pressure measurement or the sum of application footprints. Public host APIs can fail and can return cached statistics under system rate limits. [Apple XNU implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/host.c), [Apple host_statistics64](https://developer.apple.com/documentation/kernel/1502863-host_statistics64)

Implementation/source acceptance:

- [x] Add optional system CPU/RAM snapshot fields independently from existing app CPU/footprint fields; handle failed calls, unavailable baseline, invalid deltas/page arithmetic and foreground rebaseline.
- [x] Change Hardware and History to system readings, with system CPU 100% representing all cores and RAM estimate normalized by physical capacity.
- [x] Retain separately named app-process values in Details; localize system/app scope, RAM estimate/cache inclusion and Simulator host note in all four languages.
- [x] Add distinct optional system fields to ActivityKit and render unavailable for legacy content without those fields; do not fall back to app readings.
- [x] Update README and the metric-scope table with the final system/app distinction, estimate definition, rate-limit/unavailable handling and unchanged Home Screen widget scope.
- [x] Run the integrated Debug/Release build and focused system-counter/math/legacy-payload validation; record Root's actual results.

Runtime/accuracy acceptance:

- [ ] Inspect final Dashboard/History/Details system labels, units, estimate note and baseline/unavailable behavior in Simulator; no app value may be mislabeled as system data.
- [ ] Observe updated Live Activity system readings with the original last-update/stale behavior; retain a clear unavailable presentation for older payloads.
- [ ] Inspect rendered labels in all four languages; preserve the Resource dial hierarchy and current section spacing.
- [ ] Verify system CPU/RAM behavior on a physical iPhone. Simulator/native Mac host-statistics observations are host-only integration evidence, not iPhone-wide accuracy proof.

Root validation: final Debug build/run and unsigned generic-iOS Release build passed; all 15 XCTest tests passed. Four-language source coverage passes with 127 app keys and 33 widget keys per language. Actual English Dashboard system labels, units, estimate note and Simulator host note fit (`Validation/system-telemetry-dashboard-en.png`). History/Details changes are source-reviewed; their rendered layouts remain open. Live Activity activation succeeded in the app, but the attempted lock-screen capture did not show an activity. Further UI inspection was blocked by another task using the shared Device Hub window; lock-screen rendering remains unverified. See `Validation/REPORT.md` for evidence. Home Screen widgets remain battery/thermal/storage snapshots and do not gain a CPU polling loop. Public Darwin API use does not imply unrestricted per-process enumeration, guaranteed fresh samples or an App Store acceptance claim.


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


## Configurable display revision — 2026-10-13

- [x] Persist ordered 1–3 Live Activity metric selections with safe legacy/invalid fallback.
- [x] Update current activities immediately and render only selected metric tiles; first item drives compact Island.
- [x] Register per-instance WidgetKit App Intent configuration for Battery/Temperature/Storage/RAM and optional None slots.
- [x] Preserve 30-minute requested refresh, 60-minute stale fallback, capture time and configured RAM values.
- [x] Localize settings, metric names, intent parameters and estimate hints in all four languages.
- [x] Debug/unsigned Release builds, 23 XCTest tests, 23 Widget model assertions plus 3 policy checks, localization parity/coverage.
- [x] Actual English selection persistence, immediate active Live Activity layout change and small/medium/large configured widget rendering verified in Simulator.
- [ ] Physical-device, translated rendered layouts, accessibility and expanded Island verification.

Evidence and exact limitations: Validation/REPORT.md, configurable display section. This revision expands prior Home widget scope with one-shot System RAM and permits local Live Activity storage display only when selected. Earlier app-only/widget-scope notes are historical and are superseded by this section.


## Modular restructuring — 2026-10-13

- [x] Extract local MonitorDomain, MonitorTelemetry and MonitorActivity package products with explicit app/widget/test dependencies.
- [x] Separate app lifecycle services, feature screens, components and design system.
- [x] Split widget presentation into focused files; retain original rendering logic.
- [x] Regenerate Xcode project, Debug/Release builds and 23 XCTest checks.
- [x] Validate four locales, original frames, actual Dashboard/Live Activity/medium Home Widget.
- [x] Document architecture and reproducible clone/build steps.
- [x] Commit and push against existing GitHub main history.
