import EventKit
import SwiftUI

struct NewCalendarSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var sourceID = ""
    @State private var errorMessage: String?
    let onCreate: (EKCalendar) -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Calendar Name", text: $title)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    if model.creatableSources.isEmpty {
                        Text("No account can create calendars. Add an iCloud account in Settings.")
                            .foregroundStyle(.secondary)
                    } else if model.creatableSources.count == 1, let source = model.creatableSources.first {
                        Text(source.title)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Account", selection: $sourceID) {
                            ForEach(model.creatableSources, id: \.sourceIdentifier) { source in
                                Text(source.title).tag(source.sourceIdentifier)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Calendars in On My iPhone stay on this device. To share a calendar, create it in iCloud and share it in Calendar.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(trimmedTitle.isEmpty || sourceID.isEmpty)
                }
            }
            .onAppear {
                if sourceID.isEmpty {
                    sourceID = model.defaultCalendarSourceID
                        ?? model.creatableSources.first?.sourceIdentifier
                        ?? ""
                }
            }
        }
    }

    private func create() {
        do {
            let calendar = try model.createCalendar(title: trimmedTitle, sourceID: sourceID)
            onCreate(calendar)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
