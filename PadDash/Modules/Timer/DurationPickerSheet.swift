import SwiftUI

// MARK: - Duration Picker Sheet

struct DurationPickerSheet: View {
    @ObservedObject var vm: TimerSlotVM

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Text("Set Duration")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Color.textPrimary)
                Spacer()
                Button {
                    vm.isEditingDuration = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DS.Color.textSecondary)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)
            .padding(.bottom, DS.Space.sm)

            Divider().background(DS.Color.border)

            // Quick Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.xs) {
                    ForEach(DashTimer.presets, id: \.seconds) { preset in
                        Button {
                            vm.applyPreset(seconds: preset.seconds)
                        } label: {
                            Text(preset.label)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(vm.accent)
                                .padding(.horizontal, DS.Space.sm)
                                .padding(.vertical, 8)
                                .background(vm.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
            }

            Divider().background(DS.Color.border)

            // Wheel pickers
            HStack(spacing: 0) {
                PickerColumn(value: $vm.pickerHours,   range: 0..<24, label: "hr")
                PickerColumn(value: $vm.pickerMinutes, range: 0..<60, label: "min")
                PickerColumn(value: $vm.pickerSeconds, range: 0..<60, label: "sec")
            }
            .padding(.horizontal, DS.Space.md)

            Divider().background(DS.Color.border)

            // Apply
            Button {
                vm.applyPickerDuration()
            } label: {
                Text("Set Timer")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Color.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(vm.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
            .padding(DS.Space.md)
        }
        .background(DS.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
    }
}

// MARK: - Picker Column

private struct PickerColumn: View {
    @Binding var value: Int
    var range: Range<Int>
    var label: String

    var body: some View {
        VStack(spacing: 4) {
            Picker("", selection: $value) {
                ForEach(range, id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(DS.Color.textPrimary)
                        .tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
            .clipped()

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
