import QtQuick
import QtTest
import ".." as Dock

Item {
    width: 200; height: 200
    Dock.DockIndicators { id: indicators; x: 50; y: 50; width: 48; height: 48 }
    TestCase {
        name: "DockIndicators"
        when: windowShown
        function init() { indicators.activity = {}; indicators.urgent = false }
        function test_countVisibilityAndOverflow() {
            var badge = findChild(indicators, "dock-count-badge")
            verify(!badge.visible)
            indicators.activity = {count: 7, countVisible: true}
            verify(badge.visible)
            compare(indicators.countText, "7")
            indicators.activity = {count: 1234, countVisible: true}
            compare(indicators.countText, "99+")
            indicators.activity = {count: 1234, countVisible: false}
            verify(!badge.visible)
            indicators.activity = {count: 0, countVisible: true}
            verify(!badge.visible)
        }
        function test_progressAndExplicitHide() {
            var track = findChild(indicators, "dock-progress-track")
            var fill = findChild(indicators, "dock-progress-fill")
            indicators.activity = {progress: .35, progressVisible: true}
            verify(track.visible)
            tryVerify(function() { return Math.abs(fill.width - track.width * .35) < .01 })
            indicators.activity = {progress: 2, progressVisible: true}
            compare(indicators.progress, 1)
            indicators.activity = {progress: .35, progressVisible: false}
            verify(!track.visible)
        }
        function test_attentionWithoutInventingUnreadCount() {
            indicators.urgent = true
            verify(findChild(indicators, "dock-attention-ring").visible)
            verify(findChild(indicators, "dock-attention-dot").visible)
            verify(!findChild(indicators, "dock-count-badge").visible)
            indicators.activity = {count: 2, countVisible: true}
            verify(!findChild(indicators, "dock-attention-dot").visible)
            indicators.urgent = false
            verify(!findChild(indicators, "dock-attention-ring").visible)
        }
    }
}
