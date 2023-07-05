// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "hummingbird-spec",
    platforms: [
       .macOS(.v12),
    ],
    products: [
        .library(name: "HummingbirdSpec", targets: ["HummingbirdSpec"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            from: "1.6.0"
        ),
    ],
    targets: [
        .target(name: "HummingbirdSpec", dependencies: [
            .product(name: "Hummingbird", package: "hummingbird"),
            .product(name: "HummingbirdFoundation", package: "hummingbird"),
            .product(name: "HummingbirdXCT", package: "hummingbird"),
        ]),
        .testTarget(name: "HummingbirdSpecTests", dependencies: [
            .target(name: "HummingbirdSpec"),
        ]),
    ]
)
