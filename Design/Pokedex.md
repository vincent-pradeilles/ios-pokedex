# Generations I–III Pokédex

386 English species names are bundled in National Pokédex order from PokeAPI:
https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/pokemon_species_names.csv

Generation ranges: Kanto 001–151; Johto 152–251; Hoenn 252–386.

The original hidden-name treatment follows Emerald's numbered, dashed-name convention. Its list rendering calls CreateMonName(0, …) for unseen entries, producing ten dashes, and omits the caught marker:
https://github.com/pret/pokeemerald/blob/master/src/pokedex.c

We adapt registration to successful saved scans, using a labeled checkmark instead of a caught Poké Ball. All 386 slots remain browsable. Unscanned names remain hidden, including search and accessibility. Tracked cards open the newest saved scan. Duplicate scans count once, sample entries do not count, and later-generation scans stay in history without changing completion. Progress derives from the existing persisted history, so previous scans register automatically.


## Sprite cards

All 386 front-facing Pokémon Emerald sprites (64 × 64 PNG) are bundled for offline use from:
https://github.com/PokeAPI/sprites/tree/master/sprites/pokemon/versions/generation-iii/emerald

Pokémon and Pokémon character names are trademarks of Nintendo. Sprite artwork belongs to its respective owners, including Nintendo, Game Freak, and The Pokémon Company.

At the user’s request, the adaptive card grid displays unscanned sprites as solid black alpha-mask silhouettes on a pale green screen. Tracked entries use the original full-color sprite. Nearest-neighbor interpolation preserves the Game Boy Advance pixel art. This silhouette treatment is an intentional adaptation rather than an exact Emerald screen reproduction.
