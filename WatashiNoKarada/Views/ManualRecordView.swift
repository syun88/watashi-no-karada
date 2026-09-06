import SwiftUI
import SwiftData

struct ManualRecordView: View {
    @Environment(\.modelContext) private var context
    @State private var waist = ""
    @State private var weight = ""
    @State private var note = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("手入力") {
                HStack { Text("ウエスト"); Spacer(); TextField("cm", text: $waist).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                HStack { Text("体重"); Spacer(); TextField("kg", text: $weight).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                TextField("メモ（任意）", text: $note, axis: .vertical)
            }
            Section {
                Button("保存") { save() }
                    .frame(maxWidth: .infinity)
                    .disabled(Double(waist) == nil)
            }
            Section {
                Text("LiDARスキャンとは別に、体重計やメジャーで測った値も同じ履歴に残せます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("記録")
        .alert("保存しました", isPresented: $saved) { Button("OK", role: .cancel) {} }
    }

    private func save() {
        guard let waistValue = Double(waist) else { return }
        let record = BodyRecord(waistCM: waistValue, weightKG: Double(weight), note: note, source: "manual")
        context.insert(record)
        try? context.save()
        waist = ""; weight = ""; note = ""; saved = true
    }
}
