import SwiftUI

struct ToggleRow: View {
    var title: String
    @Binding var isOn: Bool
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack {
            Text(title)
                .font(PixelFont.section)
                .foregroundStyle(PixelColors.muted)
            Spacer()
            Button {
                isOn.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text(LocalizedCopy.text(isOn ? .on : .off, language: store.preferences.language))
                    PixelToggleMark(isOn: isOn)
                }
                .font(PixelFont.section)
                .foregroundStyle(isOn ? PixelColors.up : PixelColors.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

struct PixelMarketSelector: View {
    @Binding var selection: MarketType

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MarketType.allCases) { market in
                Button {
                    selection = market
                } label: {
                    Text(market.shortName)
                        .font(PixelFont.tiny)
                        .foregroundStyle(selection == market ? PixelColors.background : PixelColors.cyan)
                        .frame(width: 48, height: 32)
                        .background(selection == market ? PixelColors.cyan : PixelColors.background)
                        .overlay(Rectangle().stroke(selection == market ? PixelColors.cyan : PixelColors.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 144)
    }
}

struct PixelLanguageSelector: View {
    @Binding var selection: AppLanguage

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    selection = language
                } label: {
                    Text(language.title)
                        .font(PixelFont.tiny)
                        .foregroundStyle(selection == language ? PixelColors.background : PixelColors.cyan)
                        .frame(width: 52, height: 28)
                        .background(selection == language ? PixelColors.cyan : PixelColors.background)
                        .overlay(Rectangle().stroke(selection == language ? PixelColors.cyan : PixelColors.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 104)
    }
}

struct PixelIntradayIntervalSelector: View {
    @Binding var selection: IntradayInterval

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IntradayInterval.allCases) { interval in
                Button {
                    selection = interval
                } label: {
                    Text(interval.title)
                        .font(PixelFont.tiny)
                        .foregroundStyle(selection == interval ? PixelColors.background : PixelColors.cyan)
                        .frame(width: 46, height: 28)
                        .background(selection == interval ? PixelColors.cyan : PixelColors.background)
                        .overlay(Rectangle().stroke(selection == interval ? PixelColors.cyan : PixelColors.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 138)
    }
}

struct PixelChartDisplayModeSelector: View {
    @Binding var selection: IntradayChartDisplayMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IntradayChartDisplayMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(mode.title)
                        .font(PixelFont.tiny)
                        .foregroundStyle(selection == mode ? PixelColors.background : PixelColors.cyan)
                        .frame(width: 54, height: 28)
                        .background(selection == mode ? PixelColors.cyan : PixelColors.background)
                        .overlay(Rectangle().stroke(selection == mode ? PixelColors.cyan : PixelColors.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 108)
    }
}

struct PixelStepper: View {
    var value: Int
    var range: ClosedRange<Int>
    var onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                onChange(max(range.lowerBound, value - 1))
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(PixelIconButtonStyle(tint: PixelColors.cyan))
            .disabled(value <= range.lowerBound)

            Text("\(value)")
                .font(PixelFont.section)
                .foregroundStyle(PixelColors.text)
                .frame(width: 24, alignment: .center)
                .padding(.vertical, 5)
                .background(PixelColors.background)
                .overlay(Rectangle().stroke(PixelColors.line, lineWidth: 1))

            Button {
                onChange(min(range.upperBound, value + 1))
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(PixelIconButtonStyle(tint: PixelColors.cyan))
            .disabled(value >= range.upperBound)
        }
    }
}

struct PixelField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(PixelFont.body)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(PixelColors.background)
            .overlay(Rectangle().stroke(PixelColors.line, lineWidth: 1))
    }
}

struct PixelSecureField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .font(PixelFont.body)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(PixelColors.background)
            .overlay(Rectangle().stroke(PixelColors.line, lineWidth: 1))
    }
}

struct PixelIconButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(configuration.isPressed ? PixelColors.background : tint)
            .frame(width: 24, height: 24)
            .background(configuration.isPressed ? tint : PixelColors.background)
            .overlay(Rectangle().stroke(tint.opacity(configuration.isPressed ? 1 : 0.75), lineWidth: 1))
    }
}

private struct PixelToggleMark: View {
    var isOn: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isOn ? PixelColors.up : PixelColors.background)
                .frame(width: 24, height: 16)
                .overlay(Rectangle().stroke(isOn ? PixelColors.up : PixelColors.line, lineWidth: 1))
            Rectangle()
                .fill(isOn ? PixelColors.background : PixelColors.muted)
                .frame(width: 8, height: 8)
                .offset(x: isOn ? 5 : -5)
        }
    }
}
