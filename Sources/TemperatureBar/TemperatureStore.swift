import Foundation
import Observation

struct TemperatureSample: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let celsius: Double

    init(date: Date = .now, celsius: Double) {
        self.id = UUID()
        self.date = date
        self.celsius = celsius
    }
}

@MainActor
@Observable
final class TemperatureStore {
    private static let sampleInterval: TimeInterval = 2
    private static let historyWindow: TimeInterval = 10 * 60
    private static let maxSamples = Int(historyWindow / sampleInterval) + 5

    var current: Double?
    var samples: [TemperatureSample] = []

    /// Called after every sample so AppKit can refresh the status item title.
    var onSample: (() -> Void)?

    var menuBarText: String {
        guard let current else { return "—" }
        return "\(Int(current.rounded()))°"
    }

    var minInWindow: Double? {
        samples.map(\.celsius).min()
    }

    var maxInWindow: Double? {
        samples.map(\.celsius).max()
    }

    private let reader: ThermalReader?

    init(reader: ThermalReader? = ThermalReader()) {
        self.reader = reader
        sample()
        startTimer()
    }

    func sample() {
        if let temp = reader?.readCPUTemperature() {
            current = temp
            samples.append(TemperatureSample(celsius: temp))
        } else {
            current = nil
        }
        trimHistory()
        onSample?()
    }

    private func startTimer() {
        let timer = Timer(timeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sample()
            }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
    }

    private func trimHistory() {
        let cutoff = Date.now.addingTimeInterval(-Self.historyWindow)
        samples.removeAll { $0.date < cutoff }
        if samples.count > Self.maxSamples {
            samples.removeFirst(samples.count - Self.maxSamples)
        }
    }
}
