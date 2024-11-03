// swift-tools-version:5.9

import PackageDescription
import Foundation

let coreVersion = Version("13.26.0")
let cocoaVersion = Version("10.48.0")

let cxxSettings: [CXXSetting] = [
    .headerSearchPath("."),
    .headerSearchPath("include"),
    .define("REALM_SPM", to: "1"),
    .define("REALM_ENABLE_SYNC", to: "1"),
    .define("REALM_COCOA_VERSION", to: "@\"\(cocoaVersion)\""),
    .define("REALM_VERSION", to: "\"\(coreVersion)\""),
    .define("REALM_IOPLATFORMUUID", to: "@\"\(runCommand())\""),

    .define("REALM_DEBUG", .when(configuration: .debug)),
    .define("REALM_NO_CONFIG"),
    .define("REALM_INSTALL_LIBEXECDIR", to: ""),
    .define("REALM_ENABLE_ASSERTIONS", to: "1"),
    .define("REALM_ENABLE_ENCRYPTION", to: "1"),

    .define("REALM_VERSION_MAJOR", to: String(coreVersion.major)),
    .define("REALM_VERSION_MINOR", to: String(coreVersion.minor)),
    .define("REALM_VERSION_PATCH", to: String(coreVersion.patch)),
    .define("REALM_VERSION_EXTRA", to: "\"\(coreVersion.prereleaseIdentifiers.first ?? "")\""),
    .define("REALM_VERSION_STRING", to: "\"\(coreVersion)\""),
    .define("REALM_ENABLE_GEOSPATIAL", to: "1"),
]
let testCxxSettings: [CXXSetting] = cxxSettings + [
    // Command-line `swift build` resolves header search paths
    // relative to the package root, while Xcode resolves them
    // relative to the target root, so we need both.
    .headerSearchPath("Realm"),
    .headerSearchPath(".."),
]

// SPM requires all targets to explicitly include or exclude every file, which
// gets very awkward when we have four targets building from a single directory

func runCommand() -> String {
    let task = Process()
    let pipe = Pipe()

    task.executableURL = URL(fileURLWithPath: "/usr/sbin/ioregg")
    task.arguments = ["-rd1", "-c", "IOPlatformExpertDevice"]
    task.standardInput = nil
    task.standardError = nil
    task.standardOutput = pipe
    do {
        try task.run()
    } catch {
        return ""
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    let range = NSRange(output.startIndex..., in: output)
    guard let regex = try? NSRegularExpression(pattern: ".*\\\"IOPlatformUUID\\\"\\s=\\s\\\"(.+)\\\"", options: .caseInsensitive),
          let firstMatch = regex.matches(in: output, range: range).first else {
        return ""
    }

    let matches = (0..<firstMatch.numberOfRanges).compactMap { ind -> String? in
        let matchRange = firstMatch.range(at: ind)
        if matchRange != range,
           let substringRange = Range(matchRange, in: output) {
            let capture = String(output[substringRange])
            return capture
        }
        return nil
    }
    return matches.last ?? ""
}

let package = Package(
    name: "RealmLegacy",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v4)
    ],
    products: [
//        .library(
//            name: "RealmLegacy",
//            targets: ["RealmLegacy"]),
        .library(
            name: "RealmSwiftLegacy",
            targets: ["RealmLegacy", "RealmSwiftLegacy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lake-of-fire/realm-core-legacy.git", branch: "legacy")
    ],
    targets: [
      .target(
            name: "RealmLegacy",
            dependencies: [.product(name: "RealmCoreLegacy", package: "realm-core-legacy")],
            path: ".",
            exclude: [
                "CHANGELOG.md",
                "CONTRIBUTING.md",
                "Configuration",
                "LICENSE",
                "Package.swift",
                "README.md",
                "Realm.xcodeproj",
                "Realm/Realm-Info.plist",
                "Realm/Swift/LEGACYSupport.swift",
                "RealmSwift",
                "SUPPORT.md",
                "dependencies.list",
                "include",
            ],
            sources: [
                "Realm/LEGACYAccessor.mm",
                "Realm/LEGACYAnalytics.mm",
                "Realm/LEGACYArray.mm",
                "Realm/LEGACYAsymmetricObject.mm",
                "Realm/LEGACYAsyncTask.mm",
                "Realm/LEGACYClassInfo.mm",
                "Realm/LEGACYCollection.mm",
                "Realm/LEGACYConstants.m",
                "Realm/LEGACYDecimal128.mm",
                "Realm/LEGACYDictionary.mm",
                "Realm/LEGACYEmbeddedObject.mm",
                "Realm/LEGACYError.mm",
                "Realm/LEGACYEvent.mm",
                "Realm/LEGACYGeospatial.mm",
                "Realm/LEGACYLogger.mm",
                "Realm/LEGACYManagedArray.mm",
                "Realm/LEGACYManagedDictionary.mm",
                "Realm/LEGACYManagedSet.mm",
                "Realm/LEGACYMigration.mm",
                "Realm/LEGACYObject.mm",
                "Realm/LEGACYObjectBase.mm",
                "Realm/LEGACYObjectId.mm",
                "Realm/LEGACYObjectSchema.mm",
                "Realm/LEGACYObjectStore.mm",
                "Realm/LEGACYObservation.mm",
                "Realm/LEGACYPredicateUtil.mm",
                "Realm/LEGACYProperty.mm",
                "Realm/LEGACYQueryUtil.mm",
                "Realm/LEGACYRealm.mm",
                "Realm/LEGACYRealmConfiguration.mm",
                "Realm/LEGACYRealmUtil.mm",
                "Realm/LEGACYResults.mm",
                "Realm/LEGACYScheduler.mm",
                "Realm/LEGACYSchema.mm",
                "Realm/LEGACYSectionedResults.mm",
                "Realm/LEGACYSet.mm",
                "Realm/LEGACYSwiftCollectionBase.mm",
                "Realm/LEGACYSwiftSupport.m",
                "Realm/LEGACYSwiftValueStorage.mm",
                "Realm/LEGACYThreadSafeReference.mm",
                "Realm/LEGACYUUID.mm",
                "Realm/LEGACYUpdateChecker.mm",
                "Realm/LEGACYUtil.mm",
                "Realm/LEGACYValue.mm",

                // Sync source files
                "Realm/NSError+LEGACYSync.m",
                "Realm/LEGACYApp.mm",
                "Realm/LEGACYAPIKeyAuth.mm",
                "Realm/LEGACYBSON.mm",
                "Realm/LEGACYCredentials.mm",
                "Realm/LEGACYEmailPasswordAuth.mm",
                "Realm/LEGACYFindOneAndModifyOptions.mm",
                "Realm/LEGACYFindOptions.mm",
                "Realm/LEGACYMongoClient.mm",
                "Realm/LEGACYMongoCollection.mm",
                "Realm/LEGACYNetworkTransport.mm",
                "Realm/LEGACYProviderClient.mm",
                "Realm/LEGACYPushClient.mm",
                "Realm/LEGACYRealm+Sync.mm",
                "Realm/LEGACYSyncConfiguration.mm",
                "Realm/LEGACYSyncManager.mm",
                "Realm/LEGACYSyncSession.mm",
                "Realm/LEGACYSyncSubscription.mm",
                "Realm/LEGACYSyncUtil.mm",
                "Realm/LEGACYUpdateResult.mm",
                "Realm/LEGACYUser.mm",
                "Realm/LEGACYUserAPIKey.mm"
            ],
            resources: [
                .copy("Realm/PrivacyInfo.xcprivacy")
            ],
            publicHeadersPath: "include",
            cxxSettings: cxxSettings,
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS, .macCatalyst, .tvOS, .watchOS]))
            ]
        ),
        .target(
            name: "RealmSwiftLegacy",
            dependencies: ["RealmLegacy"],
            path: "RealmSwift",
            exclude: [
                "Nonsync.swift",
                "RealmSwift-Info.plist",
                "Tests",
            ],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
//        .target(
//            name: "RealmTestSupport",
//            dependencies: ["Realm"],
//            path: "Realm/TestUtils",
//            cxxSettings: testCxxSettings
//        ),
//        .target(
//            name: "RealmSwiftTestSupport",
//            dependencies: ["RealmSwift", "RealmTestSupport"],
//            path: "RealmSwift/Tests",
//            sources: ["TestUtils.swift"]
//        ),
//        .testTarget(
//            name: "RealmTests",
//            dependencies: ["Realm", "RealmTestSupport"],
//            path: "Realm/Tests",
//            exclude: [
//                "PrimitiveArrayPropertyTests.tpl.m",
//                "PrimitiveDictionaryPropertyTests.tpl.m",
//                "PrimitiveLEGACYValuePropertyTests.tpl.m",
//                "PrimitiveSetPropertyTests.tpl.m",
//                "RealmTests-Info.plist",
//                "Swift",
//                "SwiftUITestHost",
//                "SwiftUITestHostUITests",
//                "TestHost",
//                "array_tests.py",
//                "dictionary_tests.py",
//                "fileformat-pre-null.realm",
//                "mixed_tests.py",
//                "set_tests.py",
//                "SwiftUISyncTestHost",
//                "SwiftUISyncTestHostUITests"
//            ],
//            cxxSettings: testCxxSettings
//        ),
//        .testTarget(
//            name: "RealmObjcSwiftTests",
//            dependencies: ["Realm", "RealmTestSupport"],
//            path: "Realm/Tests/Swift",
//            exclude: ["RealmObjcSwiftTests-Info.plist"]
//        ),
//        .testTarget(
//            name: "RealmSwiftTests",
//            dependencies: ["RealmSwift", "RealmTestSupport", "RealmSwiftTestSupport"],
//            path: "RealmSwift/Tests",
//            exclude: [
//                "RealmSwiftTests-Info.plist",
//                "QueryTests.swift.gyb",
//                "TestUtils.swift"
//            ]
//        ),

        // Object server tests have support code written in both obj-c and
        // Swift which is used by both the obj-c and swift test code. SPM
        // doesn't support mixed targets, so this ends up requiring four
        // different targets.
//        objectServerTestSupportTarget(
//            name: "RealmSyncTestSupport",
//            dependencies: ["Realm", "RealmSwift", "RealmTestSupport"],
//            sources: [
//                "LEGACYServerTestObjects.m",
//                "LEGACYSyncTestCase.mm",
//                "LEGACYUser+ObjectServerTests.mm",
//                "LEGACYWatchTestUtility.m",
//            ]
//        ),
//        objectServerTestSupportTarget(
//            name: "RealmSwiftSyncTestSupport",
//            dependencies: ["RealmSwift", "RealmTestSupport", "RealmSyncTestSupport", "RealmSwiftTestSupport"],
//            sources: [
//                 "RealmServer.swift",
//                 "SwiftServerObjects.swift",
//                 "SwiftSyncTestCase.swift",
//                 "TimeoutProxyServer.swift",
//                 "WatchTestUtility.swift",
//            ]
//        ),
//        objectServerTestTarget(
//            name: "SwiftObjectServerTests",
//            sources: [
//                "AsyncSyncTests.swift",
//                "ClientResetTests.swift",
//                "CombineSyncTests.swift",
//                "EventTests.swift",
//                "SwiftAsymmetricSyncServerTests.swift",
//                "SwiftCollectionSyncTests.swift",
//                "SwiftFlexibleSyncServerTests.swift",
//                "SwiftMongoClientTests.swift",
//                "SwiftObjectServerPartitionTests.swift",
//                "SwiftObjectServerTests.swift",
//                "SwiftUIServerTests.swift",
//            ]
//        ),
//        objectServerTestTarget(
//            name: "ObjcObjectServerTests",
//            sources: [
//                "LEGACYAsymmetricSyncServerTests.mm",
//                "LEGACYBSONTests.mm",
//                "LEGACYCollectionSyncTests.mm",
//                "LEGACYFlexibleSyncServerTests.mm",
//                "LEGACYMongoClientTests.mm",
//                "LEGACYObjectServerPartitionTests.mm",
//                "LEGACYObjectServerTests.mm",
//                "LEGACYSubscriptionTests.mm",
//            ]
//        )
    ],
    cxxLanguageStandard: .cxx20
)
