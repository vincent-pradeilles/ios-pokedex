import SwiftUI

struct JournalView: View {
  var model: DexModel
  @Environment(\.dismiss) private var dismiss
  @State private var generation = 0
  @State private var filter: TrackingFilter = .all
  @State private var query = ""
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let scans = model.latestScans
    let tracked = model.trackedSpecies
    let species = PokemonSpecies.all.filter {
      (generation == 0 || $0.generation == generation)
    }
    let visible = species.filter { pokemon in
      let found = tracked.contains(pokemon.number)
      let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
      return (filter == .all || (filter == .tracked ? found : !found)) &&
        (search.isEmpty || String(format: "%03d", pokemon.number).contains(search.replacingOccurrences(of: "#", with: "")) ||
         (found && pokemon.name.localizedStandardContains(search)))
    }
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Section {
            VStack(alignment: .leading, spacing: 12) {
              Text("NATIONAL POKÉDEX").font(.caption.monospaced()).foregroundStyle(.secondary)
              Text("\(tracked.count) / 386 tracked").font(.title2.bold()).monospacedDigit()
              ProgressView(value: Double(tracked.count), total: 386)
                .accessibilityLabel("National Pokédex completion")
              Text("Generations I–III • Kanto, Johto & Hoenn").font(.subheadline).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
            Picker("Generation", selection: $generation) {
              Text("All generations").tag(0)
              Text("I · Kanto").tag(1)
              Text("II · Johto").tag(2)
              Text("III · Hoenn").tag(3)
            }
            Picker("Show", selection: $filter) {
              ForEach(TrackingFilter.allCases) { Text($0.rawValue).tag($0) }
            }
          } footer: {
            Text("Unscanned entries appear as silhouettes with hidden names. Scan a Pokémon to reveal it. Search by number or a tracked name.")
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
            Text("\(species.filter { tracked.contains($0.number) }.count) of \(species.count) tracked · \(visible.count) shown")
          }
        }.padding().frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationTitle("Pokédex")
      .searchable(text: $query, prompt: "Pokédex number or tracked name")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", systemImage: "checkmark") { dismiss() }
        }
      }
    }.tint(.red)
  }
}

private enum TrackingFilter: String, CaseIterable, Identifiable {
  case all = "All Pokémon"
  case tracked = "Tracked"
  case unscanned = "Not scanned"
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
        Image("pokemon-\(species.number)")
          .renderingMode(entry == nil ? .template : .original)
          .resizable()
          .interpolation(.none)
          .scaledToFit()
          .foregroundStyle(.black)
          .frame(width: 96, height: 96)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(Color(red: 0.82, green: 0.88, blue: 0.77), in: RoundedRectangle(cornerRadius: 12))
          .accessibilityHidden(true)
        Text(entry == nil ? "––––––––––" : species.name)
          .font(.body.monospaced().weight(.semibold))
          .lineLimit(2, reservesSpace: true)
          .multilineTextAlignment(.center)
          .foregroundStyle(.primary)
        Text(entry == nil ? "Not scanned" : "Tracked")
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
    .accessibilityLabel(entry == nil ? "Number \(species.number), not scanned" : "Number \(species.number), \(species.name), tracked")
    .accessibilityHint(entry == nil ? "Scan this Pokémon to reveal its entry" : "Opens your latest saved scan")
  }
}
