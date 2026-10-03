import SwiftUI

struct JournalView: View {
  var model: DexModel
  @Environment(\.dismiss) private var dismiss
  @State private var generation = 0
  @State private var filter: CaptureFilter = .all
  @State private var query = ""
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let scans = model.latestScans
    let captured = model.capturedSpecies
    let species = PokemonSpecies.all.filter {
      (generation == 0 || $0.generation == generation)
    }
    let visible = species.filter { pokemon in
      let found = captured.contains(pokemon.number)
      let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
      return (filter == .all || (filter == .captured ? found : !found)) &&
        (search.isEmpty || String(format: "%03d", pokemon.number).contains(search.replacingOccurrences(of: "#", with: "")) ||
         (found && pokemon.name.localizedStandardContains(search)))
    }
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Section {
            VStack(alignment: .leading, spacing: 12) {
              Text("NATIONAL POKÉDEX").font(.caption.monospaced()).foregroundStyle(.secondary)
              Text("\(captured.count) / 386 captured").font(.title2.bold()).monospacedDigit()
              ProgressView(value: Double(captured.count), total: 386)
                .accessibilityLabel("National Pokédex completion")
              Text("Generations I–III • Kanto, Johto & Hoenn").font(.subheadline).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
            Picker("Generation", selection: $generation) {
              Text("All generations").tag(0)
              Text("I · Kanto").tag(1)
              Text("II · Johto").tag(2)
              Text("III · Hoenn").tag(3)
            }
            Picker("Pokémon status", selection: $filter) {
              ForEach(CaptureFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
          } footer: {
            Text("Unknown entries appear as silhouettes with hidden names. Scan a Pokémon to reveal it. Search by number or a captured Pokémon’s name.")
          }
          Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 240 : 140), spacing: 12)], spacing: 12) {
            ForEach(visible) { pokemon in
              PokemonCatalogCard(species: pokemon, entry: scans[pokemon.number], busy: model.busy) { entry in
                model.select(entry)
                dismiss()
              }
            }
            }
            if visible.isEmpty {
              Text("No entries match. Try another number or filter.")
                .foregroundStyle(.secondary).padding(.vertical)
            }
          } header: {
            Text("\(species.filter { captured.contains($0.number) }.count) of \(species.count) captured · \(visible.count) shown")
          }
        }.padding().frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationTitle("Pokédex")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $query, prompt: "Pokédex number or captured Pokémon’s name")
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Pokédex")
            .font(.largeTitle.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .accessibilityAddTraits(.isHeader)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", systemImage: "checkmark") { dismiss() }
        }
      }
    }.tint(.red)
  }
}

private enum CaptureFilter: String, CaseIterable, Identifiable {
  case all = "All"
  case captured = "Captured"
  case unknown = "Unknown"
  var id: Self { self }
}

private struct PokemonCatalogCard: View {
  var species: PokemonSpecies
  var entry: DexEntry?
  var busy: Bool
  var select: (DexEntry) -> Void

  var body: some View {
    Button {
      if let entry { select(entry) }
    } label: {
      VStack(spacing: 10) {
        Text(String(format: "No. %03d", species.number))
          .font(.caption.monospaced()).foregroundStyle(.secondary)
        PokemonCardImage(number: species.number, entry: entry)
        Text(entry == nil ? "––––––––––" : species.name)
          .font(.body.monospaced().weight(.semibold))
          .lineLimit(2, reservesSpace: true)
          .multilineTextAlignment(.center)
          .foregroundStyle(.primary)
        Text(entry == nil ? "Unknown" : "Captured")
          .font(.caption.weight(.medium)).foregroundStyle(.secondary)
      }
      .padding(12)
      .frame(maxWidth: .infinity)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18).strokeBorder(entry == nil ? Color.secondary.opacity(0.2) : Color.red.opacity(0.6))
      }
      .contentShape(RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
    .disabled(entry == nil || busy)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(entry == nil ? "Number \(species.number), unknown" : "Number \(species.number), \(species.name), captured")
    .accessibilityHint(entry == nil ? "Scan this Pokémon to reveal its entry" : "Opens your latest saved scan")
  }
}
