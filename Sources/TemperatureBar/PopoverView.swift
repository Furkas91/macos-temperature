import Charts
import SwiftUI

struct PopoverView: View {
    @Environment(TemperatureStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            chart
            footer
        }
        .padding(16)
        .frame(width: 280, height: 200)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(store.menuBarText)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(temperatureColor(store.current))

            Spacer()

            if let min = store.minInWindow, let max = store.maxInWindow {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("min \(Int(min.rounded()))°")
                    Text("max \(Int(max.rounded()))°")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if store.samples.count >= 2 {
            Chart(store.samples) { sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("°C", sample.celsius)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [temperatureColor(store.current).opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("°C", sample.celsius)
                )
                .foregroundStyle(temperatureColor(store.current))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let temp = value.as(Double.self) {
                            Text("\(Int(temp.rounded()))°")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Collecting…",
                systemImage: "thermometer.medium",
                description: Text("Need a few more samples for the chart.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack {
            Text("CPU · last 10 min")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .keyboardShortcut("q")
        }
    }

    private var yDomain: ClosedRange<Double> {
        let values = store.samples.map(\.celsius)
        guard let lo = values.min(), let hi = values.max() else {
            return 30...90
        }
        let pad = Swift.max(2.0, (hi - lo) * 0.15)
        let lower = Swift.max(0.0, lo - pad)
        let upper = hi + pad
        if upper - lower < 8 {
            let mid = (lower + upper) / 2
            return (mid - 4)...(mid + 4)
        }
        return lower...upper
    }

    private func temperatureColor(_ temp: Double?) -> Color {
        guard let temp else { return .primary }
        if temp >= 90 { return .red }
        if temp >= 80 { return .orange }
        return .primary
    }
}
