import SwiftUI
import FirebaseFirestore

struct EventSetupView: View {
    var editingEvent: AppEvent? = nil

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var endTime = Date().addingTimeInterval(8 * 3600)
    @State private var doorsOpen = Date()
    @State private var lastEntry = Date().addingTimeInterval(4 * 3600)
    @State private var venue = "Mansion Nightclub, Liverpool"
    @State private var ageRestriction = 18
    @State private var status = EventStatus.draft
    @State private var tiers: [TierDraft] = [TierDraft()]
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private let db = Firestore.firestore()

    var isEditing: Bool { editingEvent != nil }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        formSection("EVENT DETAILS") {
                            VStack(spacing: 12) {
                                setupField("Event Name", text: $name)
                                setupTextEditor("Description", text: $description)
                                setupField("Venue", text: $venue)

                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Age Restriction")
                                            .font(.caption).foregroundColor(.textSecondary)
                                        Picker("Age", selection: $ageRestriction) {
                                            ForEach([18, 19, 21], id: \.self) { age in
                                                Text("\(age)+").tag(age)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Status")
                                            .font(.caption).foregroundColor(.textSecondary)
                                        Picker("Status", selection: $status) {
                                            Text("Draft").tag(EventStatus.draft)
                                            Text("Published").tag(EventStatus.published)
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                }
                            }
                        }

                        formSection("DATES & TIMES") {
                            VStack(spacing: 0) {
                                dateRow("Event Date", selection: $date)
                                Divider().background(Color.divider)
                                dateRow("Doors Open", selection: $doorsOpen)
                                Divider().background(Color.divider)
                                dateRow("Last Entry", selection: $lastEntry)
                                Divider().background(Color.divider)
                                dateRow("End Time", selection: $endTime)
                            }
                            .background(Color.surface)
                            .cornerRadius(14)
                        }

                        formSection("TICKET TIERS") {
                            VStack(spacing: 12) {
                                ForEach($tiers) { $tier in
                                    TierDraftRow(tier: $tier, allTiers: tiers) {
                                        tiers.removeAll { $0.id == tier.id }
                                    }
                                }

                                Button {
                                    tiers.append(TierDraft())
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Tier")
                                    }
                                    .font(.titleMedium)
                                    .foregroundColor(.brand)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.surface)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brand.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        Button(action: saveEvent) {
                            ZStack {
                                if saving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isEditing ? "Save Changes" : (status == .published ? "Publish Event" : "Save Draft"))
                                        .font(.titleMedium)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(name.isEmpty ? Color.surface : Color.brand)
                            .cornerRadius(14)
                        }
                        .disabled(name.isEmpty || saving)

                        if isEditing {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Event", systemImage: "trash")
                                    .font(.bodyMedium)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.surface)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
                            }
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEditing ? "Edit Event" : "Create Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.brand)
                }
            }
            .onAppear(perform: populateFromEvent)
        }
        .preferredColorScheme(.dark)
        .alert("Delete Event?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive, action: deleteEvent)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \"\(editingEvent?.name ?? "this event")\". This cannot be undone.")
        }
    }

    private func populateFromEvent() {
        guard let e = editingEvent else { return }
        name = e.name
        description = e.description
        venue = e.venue
        date = e.date
        doorsOpen = e.doorsOpen
        lastEntry = e.lastEntry
        endTime = e.endTime
        ageRestriction = e.ageRestriction
        status = e.status
        tiers = e.tiers.map { t in
            var d = TierDraft()
            d.tierID = t.id
            d.name = t.name
            d.description = t.description
            d.price = t.priceInPence == 0 ? "0" : String(format: "%.2f", Double(t.priceInPence) / 100)
            d.quantity = String(t.quantity)
            d.minPerOrder = t.minPerOrder
            d.maxPerOrder = t.maxPerOrder
            d.hasSaleStart = t.saleStartsAt != nil
            if let start = t.saleStartsAt { d.saleStartsAt = start }
            return d
        }
        if tiers.isEmpty { tiers = [TierDraft()] }
    }

    private func saveEvent() {
        saving = true
        errorMessage = nil

        let tierPayload: [[String: Any]] = tiers.map { t in
            [
                "id": t.tierID,
                "name": t.name,
                "description": t.description,
                "priceInPence": Int((Double(t.price) ?? 0) * 100),
                "allocation": Int(t.quantity) ?? 0,
                "sold": 0,
            ]
        }

        let payload: [String: Any] = [
            "name": name,
            "description": description,
            "venue": venue,
            "date": Timestamp(date: date),
            "doorsOpen": Timestamp(date: doorsOpen),
            "lastEntry": Timestamp(date: lastEntry),
            "endTime": Timestamp(date: endTime),
            "ageRestriction": ageRestriction,
            "capacity": tiers.reduce(0) { $0 + (Int($1.quantity) ?? 0) },
            "status": status.rawValue.uppercased(),
            "artworkGradient": ["#1a0a00", "#2d1200"],
            "tiers": tierPayload,
        ]

        Task {
            do {
                if let existing = editingEvent {
                    try await db.collection("events").document(existing.id).updateData(payload)
                } else {
                    try await db.collection("events").addDocument(data: payload)
                }
                await MainActor.run {
                    saving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    saving = false
                }
            }
        }
    }

    private func deleteEvent() {
        guard let e = editingEvent else { return }
        Task {
            try? await db.collection("events").document(e.id).delete()
            await MainActor.run { dismiss() }
        }
    }

    @ViewBuilder
    func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rectangle().fill(Color.brand).frame(width: 3, height: 14)
                Text(title).font(.label).tracking(3).foregroundColor(.brand)
            }
            content()
        }
    }

    func setupField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.textSecondary)
            TextField(label, text: text)
                .font(.bodyLarge).foregroundColor(.white)
                .padding(14)
                .background(Color.surface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 1))
        }
    }

    func setupTextEditor(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.textSecondary)
            TextEditor(text: text)
                .font(.bodyLarge).foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 80)
                .background(Color.surface)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.divider, lineWidth: 1))
        }
    }

    func dateRow(_ label: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(label).font(.bodyMedium).foregroundColor(.textSecondary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
    }
}

// MARK: - Tier Draft Model

struct TierDraft: Identifiable {
    let id = UUID().uuidString
    var tierID = UUID().uuidString
    var name = ""
    var description = ""
    var price = ""
    var quantity = ""
    var minPerOrder = 1
    var maxPerOrder = 6
    var hasSaleStart = false
    var saleStartsAt = Date()
    var dependsOnTierId: String? = nil
}

// MARK: - Tier Draft Row

struct TierDraftRow: View {
    @Binding var tier: TierDraft
    let allTiers: [TierDraft]
    let onDelete: () -> Void
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Text(tier.name.isEmpty ? "New Tier" : tier.name)
                        .font(.titleMedium)
                        .foregroundColor(tier.name.isEmpty ? .textSecondary : .white)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(14)
            }

            if expanded {
                Divider().background(Color.divider)

                VStack(spacing: 12) {
                    tierField("Tier Name", text: $tier.name)
                    tierField("Description", text: $tier.description)

                    HStack(spacing: 12) {
                        tierField("Price (£)", text: $tier.price)
                            .keyboardType(.decimalPad)
                        tierField("Allocation", text: $tier.quantity)
                            .keyboardType(.numberPad)
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Min per order").font(.caption).foregroundColor(.textSecondary)
                            Stepper("\(tier.minPerOrder)", value: $tier.minPerOrder, in: 1...10)
                                .font(.bodyMedium).foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Max per order").font(.caption).foregroundColor(.textSecondary)
                            Stepper("\(tier.maxPerOrder)", value: $tier.maxPerOrder, in: 1...20)
                                .font(.bodyMedium).foregroundColor(.white)
                        }
                    }

                    Toggle(isOn: $tier.hasSaleStart) {
                        Text("Set on-sale time").font(.bodyMedium).foregroundColor(.textSecondary)
                    }
                    .tint(.brand)

                    if tier.hasSaleStart {
                        DatePicker("On-sale date & time", selection: $tier.saleStartsAt, displayedComponents: [.date, .hourAndMinute])
                            .font(.bodyMedium)
                            .colorScheme(.dark)
                    }

                    Button(role: .destructive, action: onDelete) {
                        Label("Remove Tier", systemImage: "trash")
                            .font(.bodyMedium)
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(14)
            }
        }
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brand.opacity(0.2), lineWidth: 1))
    }

    func tierField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.textSecondary)
            TextField(label, text: text)
                .font(.bodyLarge).foregroundColor(.white)
                .padding(10)
                .background(Color.surfaceElevated)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.divider, lineWidth: 1))
        }
    }
}
