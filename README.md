# Pocket Dex

A SwiftUI Pokédex replica designed for iPhone Duo. Unfold the phone to reveal two red hardware-inspired panels, an inset scanner display, a blue keypad, and a hinge aligned with the device’s physical fold.

The app identifies Pokémon from photos using Apple’s on-device Foundation Models framework. Photoroom removes the background and adds a controllable AI shadow before the image is analyzed locally.

## Experience

- **Made for Duo:** edge-to-edge casing with a fold-aware hinge and fixed, non-scrolling main panels.
- **Closed cover:** the compact layout reproduces the exterior of the Pokédex. Unfold Duo to access scanning and controls.
- **Empty on launch:** no default Pokémon; saved discoveries remain accessible in the journal.
- **Camera or library:** take a photo or select one with the system photo picker.
- **Continuous reveal:** shimmer appears only over the selected photo. The background dissolves as the photo and cutout move together into their final framing, while identification runs.
- **Subject-aware framing:** transparent margins are excluded when fitting the Pokémon and its shadow into the display.
- **Field journal:** successful identifications and processed images are saved locally.
- **Secure configuration:** the Photoroom API key is stored in the device’s Keychain.

## Requirements

| Requirement | Details |
| --- | --- |
| Development environment | Bitrig with the iOS 27.1 SDK |
| Intended device | iPhone Duo; the open layout is the primary experience |
| Minimum deployment target | iOS 26.0 |
| Image identification | iOS 27 or later, Apple Intelligence enabled, and an available on-device model |
| Fold-aware layout APIs | iOS 27.1 or later |
| Photoroom | API key with Image Editing API access (Plus plan) and available credits |
| Network | Required for Photoroom processing; identification runs on device |

The app can launch on the minimum deployment target, but image identification and Duo-specific layout APIs have separate availability checks. Compact layouts show the closed cover rather than a complete conventional iPhone interface.

## Run in Bitrig

1. Open this project in Bitrig.
2. Build the `Pocket Dex` target using the iOS 27.1 SDK.
3. Choose iPhone Duo in the built-in simulator and unfold it to see the full interface.
4. Open Settings using the small gear key or yellow button on the right panel.
5. Enter your Photoroom API key and tap **Save key**. Settings also reports whether the local model is ready.
6. Tap the camera button or **PHOTO** to begin a scan.

The camera needs a device with an available camera and permission to use it. Use the photo picker when testing without one. Model availability can differ between a simulator and a physical device; the app reports unavailable models instead of substituting a fabricated result.

To remove the saved API key, clear its field in Settings and save again.

## Scan pipeline

1. Check that a Photoroom key and the local model are available.
2. Prepare the selected photo and upload it to Photoroom’s `POST https://image-api.photoroom.com/v2/edit` endpoint.
3. Request background removal and a transparent PNG containing the Pokémon and its AI-generated shadow. Preserve the original canvas and subject position for the reveal.
4. Publish the processed image immediately and begin the animated background dissolve and reframing.
5. In parallel with the reveal, send an image attachment to a Foundation Models `LanguageModelSession` and generate a structured identification.
6. Save recognized results to the field journal. Display a recoverable error for failed requests or uncertain matches.

### Recognition model

Recognition uses Apple’s default on-device system language model through **Foundation Models**, with an image attachment and a structured `PokemonIdentification` response. There is no bundled Pokémon-specific Core ML classifier or custom-trained model.

The result includes the species name, National Pokédex number, elemental type, and short field notes. These are AI-generated and can be inaccurate; an explicit unrecognized result is not saved as a discovery.

### Photoroom shadows

The app uses the controllable AI Shadows model with these defaults:

| Parameter | Value |
| --- | --- |
| `pr-ai-shadows-model-version` header | `2026-04-15` |
| `shadow.mode` | `ai.auto-with-overrides` |
| `shadow.softnessOverride` | `0.75` |
| `shadow.intensityOverride` | `0.35` |
| `shadow.spreadOverride` | `short` |
| `shadow.directionOverride` | `behindRight` |
| `shadow.subjectPoseOverride` | `upright` |

The subject’s shadow comes from Photoroom, not an ellipse or drop shadow drawn by the app. These defaults live in `App/ScanService.swift`; they are not currently exposed as user settings.

See the [Photoroom Image Editing guide](https://docs.photoroom.com/image-editing-api-plus-plan/quickstart-guide) and [controllable AI Shadows documentation](https://docs.photoroom.com/image-editing-api-plus-plan/ai-shadows).

## Storage and privacy

- Selected photos are sent to Photoroom for background removal and shadow generation. This consumes the configured account’s Image Editing API credits.
- The processed image is analyzed locally through Apple’s on-device model.
- The API key is stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` in Keychain. It is not committed to the project.
- Processed PNGs are saved in the app’s Documents/Scans directory. Journal metadata is stored in UserDefaults.
- The app does not implement a separate recognition server or cloud journal sync.

## Code map

| File | Responsibility |
| --- | --- |
| `App/ContentView.swift` | Main composition, photo selection, camera and sheet presentation |
| `App/DuoHardwareLayout.swift` | Physical-fold alignment and immersive presentation |
| `App/ReplicaPanels.swift` | Open Pokédex panels and controls |
| `App/DexHardware.swift` | Casing, closed cover, sensor lights, and hinge |
| `App/DisplayPanel.swift` | Scanner LCD and identification labels |
| `App/ScanReveal.swift` | Photo-only shimmer and continuous photo-to-cutout transition |
| `App/CutoutFraming.swift` | Visible subject and shadow bounds |
| `App/DexModel.swift` | Scan lifecycle, model availability, and journal persistence |
| `App/ScanService.swift` | Photoroom request and Foundation Models inference |
| `App/KeychainStore.swift` | Secure API-key storage |
| `App/SettingsView.swift` | API configuration and model status |
| `Project.json` | Bitrig-managed target configuration and camera purpose string |

## Validation

The project has been built successfully with Bitrig. The Duo interface and saved-image framing have been inspected in the simulator. Framing calculations were checked against 36 combinations of viewport, image aspect ratio, and subject position.

For further testing, check a fresh launch, open/closed and partially folded poses, portrait/landscape layouts, camera and library selection, Reduce Motion, missing or rejected keys, unavailable local models, scan cancellation, and journal persistence. Live scanning requires a working Photoroom account and an available local model.

## Artwork and attribution

The app icon depicts an open red Pokédex. Its generation prompt and asset path are recorded in [Design/AppIcon.md](Design/AppIcon.md).

Pocket Dex is an independent fan project, not an official Pokémon product. Pokémon and Pokémon character names are trademarks of Nintendo, Creatures, and GAME FREAK.
