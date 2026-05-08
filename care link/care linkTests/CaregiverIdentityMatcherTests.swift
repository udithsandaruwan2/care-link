import XCTest
@testable import care_link

final class CaregiverIdentityMatcherTests: XCTestCase {
    func testMatchesByCaregiverId() {
        let result = CaregiverIdentityMatcher.matches(
            caregiverId: "uid_123",
            caregiverName: "Someone Else",
            knownIds: ["uid_123", "legacy_abc"],
            knownNames: []
        )
        XCTAssertTrue(result)
    }

    func testMatchesByNormalizedName() {
        let result = CaregiverIdentityMatcher.matches(
            caregiverId: "unknown",
            caregiverName: "  Dr. Sarah Lee  ",
            knownIds: [],
            knownNames: [CaregiverIdentityMatcher.normalizedName("dr. sarah lee")]
        )
        XCTAssertTrue(result)
    }

    func testDoesNotMatchWhenIdAndNameDiffer() {
        let result = CaregiverIdentityMatcher.matches(
            caregiverId: "other_uid",
            caregiverName: "Dr. Jane",
            knownIds: ["uid_123"],
            knownNames: [CaregiverIdentityMatcher.normalizedName("Dr. Sarah")]
        )
        XCTAssertFalse(result)
    }

    func testNormalizedNameTrimsAndLowercases() {
        XCTAssertEqual(
            CaregiverIdentityMatcher.normalizedName("  Dr. ALEX  "),
            "dr. alex"
        )
    }

    func testNormalizedNameCollapsesInternalWhitespace() {
        XCTAssertEqual(
            CaregiverIdentityMatcher.normalizedName("Dr.   Alex   Stone"),
            "dr. alex stone"
        )
    }

    func testEmptyKnownSetsNeverMatch() {
        let result = CaregiverIdentityMatcher.matches(
            caregiverId: "uid_123",
            caregiverName: "Dr. Alex",
            knownIds: [],
            knownNames: []
        )
        XCTAssertFalse(result)
    }

    func testCaseInsensitiveNameMatching() {
        let result = CaregiverIdentityMatcher.matches(
            caregiverId: "unknown",
            caregiverName: "DR. SARAH LEE",
            knownIds: [],
            knownNames: [CaregiverIdentityMatcher.normalizedName("dr. sarah lee")]
        )
        XCTAssertTrue(result)
    }

    func testMatchesNameWithHonorificDifferences() {
        let result = CaregiverIdentityMatcher.matches(
            caregiverId: "unknown",
            caregiverName: "Dr. Sarah Lee",
            knownIds: [],
            knownNames: [CaregiverIdentityMatcher.normalizedName("Sarah Lee")]
        )
        XCTAssertTrue(result)
    }

    func testMatchesNameWithSuffixDifferences() {
        let result = CaregiverIdentityMatcher.matches(
            caregiverId: "unknown",
            caregiverName: "Sarah Lee MD",
            knownIds: [],
            knownNames: [CaregiverIdentityMatcher.normalizedName("Dr Sarah Lee")]
        )
        XCTAssertTrue(result)
    }
}

