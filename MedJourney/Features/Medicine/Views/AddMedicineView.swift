import SwiftUI
import SwiftData

struct AddMedicineView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = MedicineViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    heroHeader
                    nameSection($vm)
                    doseSection($vm)
                    notesSection($vm)
                    remindersSection
                    saveButton
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, 48)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.rose)
                }
            }
            .sheet(isPresented: $vm.showTimePicker) {
                timePickerSheet
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(LinearGradient(
                    colors: [AppColors.rose, Color(hex: "9C4D66")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: AppColors.rose.opacity(0.28), radius: 20, y: 12)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New medicine")
                        .styled(.h3)
                        .foregroundStyle(.white)
                    Text("Set reminders and track your treatment")
                        .appFont(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "pills.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(AppSpacing.xl)
        }
        .frame(minHeight: 95)
    }

    // MARK: - Fields

    private func nameSection(_ vm: Bindable<MedicineViewModel>) -> some View {
        AppTextField(
            "Medicine name",
            text: vm.name,
            placeholder: "e.g. Paracetamol",
            icon: "pills"
        )
    }

    private func doseSection(_ vm: Bindable<MedicineViewModel>) -> some View {
        AppTextField(
            "Dose",
            text: vm.dose,
            placeholder: "e.g. 500 mg",
            icon: "scalemass"
        )
    }

    private func notesSection(_ vm: Bindable<MedicineViewModel>) -> some View {
        AppTextArea(
            "Description",
            text: vm.notes,
            placeholder: "Dosage, frequency, when to stop, side effects to watch for…",
            minHeight: 80,
            maxCharacters: 400
        )
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Reminders")
                    .styled(.labelCaps)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                Button {
                    viewModel.showTimePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add time")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppColors.rose)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 5)
                    .background(AppColors.rosePale)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if viewModel.notificationTimes.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("No reminders set — tap Add time")
                        .appFont(.body)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.border, lineWidth: 1)
                }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.notificationTimes, id: \.self) { time in
                        timeRow(time: time)
                    }
                }
            }
        }
    }

    private func timeRow(time: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.rosePale)
                    .frame(width: 34, height: 34)
                Image(systemName: "bell.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.rose)
            }

            Text(time)
                .font(.custom("DMMono-Medium", size: 17))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Button {
                withAnimation {
                    viewModel.notificationTimes.removeAll { $0 == time }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 21))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.border, lineWidth: 1)
        }
    }

    // MARK: - Time Picker

    private var timePickerSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.border)
                .frame(width: 36, height: 4)
                .padding(.top, AppSpacing.md)

            Text("Pick a time")
                .styled(.h3)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)

            HStack(alignment: .center, spacing: AppSpacing.sm) {
                wheelColumn(
                    value: viewModel.pickerHour,
                    onIncrement: { viewModel.pickerHour = (viewModel.pickerHour + 1) % 24 },
                    onDecrement: { viewModel.pickerHour = (viewModel.pickerHour - 1 + 24) % 24 }
                )

                Text(":")
                    .font(.custom("DMMono-Medium", size: 28))
                    .foregroundStyle(AppColors.textPrimary)

                wheelColumn(
                    value: viewModel.pickerMinute,
                    step: 5,
                    onIncrement: { viewModel.pickerMinute = (viewModel.pickerMinute + 5) % 60 },
                    onDecrement: { viewModel.pickerMinute = (viewModel.pickerMinute - 5 + 60) % 60 }
                )
            }
            .padding(.horizontal, AppSpacing.xxl)

            Spacer().frame(height: AppSpacing.xl)

            Button {
                viewModel.addCurrentTime()
                viewModel.showTimePicker = false
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15))
                    Text("Add reminder")
                        .appFont(.button)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.rose)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.bottom, 36)
        }
        .background(AppColors.surface)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(AppRadius.screen)
    }

    private func wheelColumn(
        value: Int,
        step: Int = 1,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Button(action: onIncrement) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(AppSpacing.xs)
            }
            .buttonStyle(ScaleButtonStyle())

            Text(String(format: "%02d", value))
                .font(.custom("DMMono-Medium", size: 30))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 58)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: onDecrement) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(AppSpacing.xs)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        AppButton(
            "Save medicine",
            style: .primary,
            icon: "checkmark",
            isFullWidth: true,
            isDisabled: !viewModel.isNameValid
        ) {
            viewModel.saveMedicine(context: context)
            dismiss()
        }
    }
}

#Preview {
    AddMedicineView()
        .modelContainer(SwiftDataContainer.create(inMemory: true))
}
