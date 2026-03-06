// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BrowserAI",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "BrowserAI",
            targets: ["BrowserAI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "BrowserAI",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)