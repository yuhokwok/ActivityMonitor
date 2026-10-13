// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonitorKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MonitorDomain", targets: ["MonitorDomain"]),
        .library(name: "MonitorTelemetry", targets: ["MonitorTelemetry"]),
        .library(name: "MonitorActivity", targets: ["MonitorActivity"])
    ],
    targets: [
        .target(name: "MonitorDomain"),
        .target(name: "MonitorTelemetry"),
        .target(name: "MonitorActivity", dependencies: ["MonitorDomain"])
    ]
)
