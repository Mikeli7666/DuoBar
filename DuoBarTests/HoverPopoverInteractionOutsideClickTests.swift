import XCTest
@testable import DuoBar

final class HoverPopoverInteractionOutsideClickTests: XCTestCase {
    func testOutsideClickWhileClosedDoesNothing() {
        var interaction = HoverPopoverInteraction(isEnabled: false)
        XCTAssertEqual(interaction.clickedOutside(), [])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testOutsideClickClosesPinnedPopoverWhenHoverIsOff() {
        var interaction = HoverPopoverInteraction(isEnabled: false)
        _ = interaction.statusItemClicked()
        XCTAssertEqual(interaction.state, .pinned)

        XCTAssertEqual(interaction.clickedOutside(), [.cancelClose, .close])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testOutsideClickClosesPinnedPopoverWhenHoverIsOn() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        _ = interaction.statusItemClicked()
        XCTAssertEqual(interaction.state, .pinned)

        XCTAssertEqual(interaction.clickedOutside(), [.cancelClose, .close])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testOutsideClickClosesHoverOpenPopover() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        XCTAssertEqual(interaction.state, .hoverOpen)

        XCTAssertEqual(interaction.clickedOutside(), [.cancelClose, .close])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testPopoverCanReopenAfterOutsideClick() {
        var interaction = HoverPopoverInteraction(isEnabled: false)
        _ = interaction.statusItemClicked()
        _ = interaction.clickedOutside()

        XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .open])
        XCTAssertEqual(interaction.state, .pinned)
    }

    func testShownExternallyTurnsClosedStateIntoPinned() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        interaction.popoverShownExternally()
        XCTAssertEqual(interaction.state, .pinned)

        XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .close])
        XCTAssertEqual(interaction.state, .closed)
    }

    func testShownExternallyDoesNotChangeOpenStates() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        interaction.popoverShownExternally()
        XCTAssertEqual(interaction.state, .hoverOpen)
    }

    func testEngagedPinsHoverOpenPopover() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        _ = interaction.statusItemEntered()
        XCTAssertEqual(interaction.popoverEngaged(), [.cancelClose])
        XCTAssertEqual(interaction.state, .pinned)
        XCTAssertEqual(interaction.closeDelayElapsed(), [])
    }

    func testEngagedDoesNothingWhenNotHoverOpen() {
        var interaction = HoverPopoverInteraction(isEnabled: true)
        XCTAssertEqual(interaction.popoverEngaged(), [])
        _ = interaction.statusItemClicked()
        XCTAssertEqual(interaction.popoverEngaged(), [])
        XCTAssertEqual(interaction.state, .pinned)
    }
}
