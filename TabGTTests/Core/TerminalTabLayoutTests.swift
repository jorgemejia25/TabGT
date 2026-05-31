import CoreGraphics
import Testing
@testable import TabGT

struct TerminalTabLayoutTests {
    @Test func distributesWidthWhenTabsFit() {
        let metrics = TerminalTabLayoutMetrics(availableWidth: 300, tabCount: 3)

        #expect(metrics.tabWidth == 100)
        #expect(metrics.needsScroll == false)
    }

    @Test func capsTabWidthAtMaximum() {
        let metrics = TerminalTabLayoutMetrics(availableWidth: 600, tabCount: 2)

        #expect(metrics.tabWidth == ShellLayout.tabMaxWidth)
        #expect(metrics.needsScroll == false)
    }

    @Test func scrollsAtMinimumWidth() {
        let metrics = TerminalTabLayoutMetrics(availableWidth: 200, tabCount: 4)

        #expect(metrics.tabWidth == ShellLayout.tabMinWidth)
        #expect(metrics.needsScroll == true)
    }

    @Test func handlesEmptyTabStrip() {
        let metrics = TerminalTabLayoutMetrics(availableWidth: 200, tabCount: 0)

        #expect(metrics.tabWidth == ShellLayout.tabMaxWidth)
        #expect(metrics.needsScroll == false)
    }
}
