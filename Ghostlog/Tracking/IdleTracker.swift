import CoreGraphics

final class IdleTracker {
    func idleSeconds() -> Double {
        let mouse    = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keyboard = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        return min(mouse, keyboard)
    }

    func isIdle(threshold: Double = 300) -> Bool {
        idleSeconds() >= threshold
    }
}
