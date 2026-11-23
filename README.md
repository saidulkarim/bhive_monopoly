# 🎲 bHiVE Monopoly

**A bilingual, responsive property-trading board game built with Flutter and Dart for Android and the Web.**

> **Project state:** Active development — **Phase 13.12** (personalization, animated dice and position glows, top-layer notifications, and test/lifecycle fixes).  
> **Flutter package:** `monopoly` · **Android application ID:** `com.bhive.monopoly`  
> **Current `pubspec.yaml` version:** `1.0.0+1` · **Dart constraint:** `^3.11.0`  
> **Documentation updated:** 23 November 2026

bHiVE Monopoly brings a classic 40-square property-trading experience to phones, tablets, and browsers. Players buy and develop properties, collect rent, participate in auctions, trade with one another, manage mortgages, and try to become the last solvent player. The application combines local Pass & Play, computer opponents, and multiplayer over a local Wi-Fi network with a premium dark, gold, and emerald visual theme.

The project has progressed through iterative development up to **Phase 13.12**. This README describes the implementation and intended behavior of the supplied phase packages and their follow-up hotfixes. It also records installation requirements, troubleshooting steps, known limitations, and verification commands. **Phase 13.12 has not been independently built and tested in this documentation environment; do not treat this file as a production-readiness certification.**

---

## Contents

1. [Highlights](#highlights)
2. [Game modes](#game-modes)
3. [Gameplay and rules](#gameplay-and-rules)
4. [Game board and user experience](#game-board-and-user-experience)
5. [Languages, fonts, and currency](#languages-fonts-and-currency)
6. [Profiles, tokens, and settings](#profiles-tokens-and-settings)
7. [LAN multiplayer](#lan-multiplayer)
8. [Saved games, history, and achievements](#saved-games-history-and-achievements)
9. [Technology stack](#technology-stack)
10. [Project architecture](#project-architecture)
11. [Installation and configuration](#installation-and-configuration)
12. [Run and build](#run-and-build)
13. [Testing and quality assurance](#testing-and-quality-assurance)
14. [Troubleshooting](#troubleshooting)
15. [Development history](#development-history)
16. [Known limitations and roadmap](#known-limitations-and-roadmap)
17. [Security, privacy, and publishing](#security-privacy-and-publishing)
18. [Contributing and license](#contributing-and-license)

---

## Highlights

| Area | Features available in the development source |
| --- | --- |
| **Platforms** | Flutter Android application and Flutter Web client; responsive portrait, landscape, and tablet layouts |
| **Play styles** | Local Pass & Play, solo versus computer, and host-authoritative local Wi-Fi multiplayer |
| **Players** | 2–6 players; versus-computer mode supports one human and up to five computer opponents |
| **Computer opponents** | Easy, Medium, and Hard AI strategies |
| **Board** | 40 squares, color groups, stations, utilities, Chance-style **Fortune** and Community-style **City Chest** spaces |
| **Transactions** | Buying, rent, auctions, trading, property development, mortgages, taxes, and bankruptcy |
| **Visuals** | Dark-gold design, responsive 2D/2.5D board, animated porcelain-style dice, motion effects for all players, ownership flags, detailed deeds |
| **Full-screen play** | Explore Board screen with pinch-to-zoom, drag-to-pan, 2D/3D toggle, horizontal zoom controls, and an exit button |
| **Live information** | Current turn, cash balance, cash leader/advantage, latest activity, and the Match Activity history panel |
| **Decisions** | Smooth bottom-up purchase, auction, jail, and debt panels; no automatic bids without user action |
| **Localization** | English/Bangla UI, configurable fonts, independent USD ($) or BDT (৳) display selection |
| **Profiles** | Local player name, 12 mutually exclusive player colors, token/avatar preferences, optional LAN photo sharing |
| **Local storage** | Offline auto-save, manual save, continue/delete saved game, previous-checkpoint recovery, match history |
| **Game experience** | Seven soft sound effects, volume, reduced motion, camera presets, optional haptics and modernized home navigation |
| **3D assets** | Five packaged GLB models in a dedicated interactive showroom |
| **Quality controls** | Game-state validation, LAN snapshot preflight, regression tests, notification lifecycle hotfixes, and a Windows release-check script |

### Project identity

- **App display name:** `bHiVE Monopoly`
- **Dart/Flutter package name:** `monopoly` (use in all `package:` imports)
- **Android application ID:** `com.bhive.monopoly` (independent of Dart package name)
- **Primary targets:** Android and Web
- **Brand style:** Obsidian / dark green, gold highlights, original bHiVE board branding and property names
- **Current development milestone:** Phase **13.12**; milestone numbers are **not** automatically the same as the `pubspec.yaml` app version (`1.0.0+1` in the supplied baseline).

---

## Game modes

### 1. Pass & Play — offline

Two to six human players share one device. Each takes a turn, rolls dice, makes purchase and auction decisions, and passes the device to the next player. No internet connection is required for core local gameplay.

### 2. Vs Computer — offline

One human player competes against one to five AI opponents. Difficulty is selectable:

| Difficulty | General behavior |
| --- | --- |
| **Easy** | Conservative/basic purchase and bidding decisions |
| **Medium** | More active buying, cash-reserve management, and development |
| **Hard** | Stronger property and bidding priorities; more strategic use of cash reserves |

The AI uses the same rules engine as human players. Animations do not decide game outcomes. New solo matches choose non-duplicate computer names from a fixed 20-name pool: **Atlas, Nova, Orion, Luna, Jasper, Sage, Ember, Milo, Aria, Felix, Zara, Theo, Iris, Leo, Maya, Finn, Cleo, River, Axel, Skye**. Saved games retain their assigned names.

### 3. Local Wi-Fi / LAN multiplayer

Host a match on a supported native device and let other players join through the same Wi-Fi network or hotspot. A six-digit room PIN and an authoritative host ensure that clients do not directly change balances or property ownership. Native discovery is best-effort; manual IP joining remains supported. See [LAN multiplayer](#lan-multiplayer).

---

## Gameplay and rules

The game uses a **40-position square board**, starting funds of **1,500**, and a **200** payment for passing/landing on the START position when applicable. The amount can display as **$1,500** or **৳1,500**, independently of the selected UI language; switching the symbol does **not** convert the underlying game values.

### Turn sequence

1. The active player rolls **two six-sided dice**.
2. The rules engine advances the player's position and processes the destination square.
3. Depending on the landing, the player may purchase property, pay rent or tax, draw a card, go to Jail, or make another required decision.
4. When a property is declined, it is offered through an auction.
5. After all required actions are resolved, the player can end the turn or take an eligible extra turn for doubles.
6. The match continues until the game engine determines the winner.

### Core mechanics

- **Properties:** Street color groups, stations, and utilities have different rent calculations.
- **Ownership bonus:** An undeveloped street in a complete color group can receive increased rent according to the title deed.
- **Buildings:** Even development rules apply to houses/hotels, subject to a bank limit of **32 houses** and **12 hotels**.
- **Auctions:** Players may place bids when the current bidding phase permits them to act.
- **Mortgages:** Eligible properties can be mortgaged and later unmortgaged.
- **Trading:** Players can exchange eligible properties and cash. LAN trading requires the receiving player's acceptance and host validation; the later multi-property trade UI permits selecting several properties in an offer.
- **Jail:** Includes jail-related rolls, fees, eligible release options, and the three-consecutive-doubles penalty.
- **Card events:** **Fortune** and **City Chest** decks provide movements, charges, rewards, and other game effects.
- **Bankruptcy:** Players can try to raise cash through permitted actions before being eliminated when debts cannot be settled.
- **Free Parking:** No default cash jackpot is awarded by the engine.

**Rules reference:** The source implements classic property-game-inspired rules with original bHiVE property/space names; review the actual `GameEngine` and its tests for precise enforcement and edge cases. It is not presented as an official licensed edition of another publisher's game.

---

## Game board and user experience

### Responsive board

The layout adapts to phone portrait, landscape, tablet, and wide-screen Web use. A top-down **2D** view is the legibility-first default; a **3D** button enables a tilted **2.5D Matrix4 tabletop perspective**. The board renders forty squares around the perimeter and exposes more detail through zoom and property inspection instead of forcing every long name to be fully readable at once on narrow phones.

### Board interaction — through Phase 13.12

| Interaction | Behavior |
| --- | --- |
| **Center dice** | A single tappable pair of dice acts as the primary Roll Dice control when the active human player is allowed to roll |
| **No duplicated action buttons** | The game avoids extra persistent Roll Dice controls in the standard mobile action area |
| **End Turn** | Offered when the turn phase permits it |
| **Latest activity** | Shows the newest game event directly below the dice; tap for the activity sheet |
| **Current cash** | Displays the current player/bidder's funds in the board center |
| **Cash leader** | Shows the richest player by **cash**, not total net worth; if the current player leads, an advantage over the next player is shown instead of duplicating the same amount |
| **Ownership pennants** | Property-edge triangles point toward the board center, use owner colors, and show selected token icons rather than player numbers |
| **House/hotel badges** | Compact overlay badges avoid adding height to small board tiles |
| **Property tap** | Opens a detailed title deed with ownership, price, mortgage and rent information |
| **Decisions** | Rounded bottom sheets slide upward for purchases, auctions, Jail and debt handling |
| **Full-screen Explore Board** | Includes player cash cards, board interactions, zoom controls, and an exit-full-screen action |
| **Zoom** | Pinch/drag or horizontal `− / percentage / + / reset / exit` toolbar beneath the board; buttons adjust zoom in **10%** steps |
| **All 40** | Opens a readable list of every board position with its key information |
| **Player-position glow** | Every non-bankrupt player has a color-coded occupied-tile border, reflective sweep and token halo; shared spaces use multicolor cues |
| **Dice during rolling** | Two separately animated tumbling dice with 3D-style motion; settled dice have clean, rounded porcelain faces |
| **Top notifications** | Solid high-contrast banners above sheets and dialogs, with a dismiss button and automatic timeout |

### Property deed view

The deed interface provides rent tiers, current ownership, costs and mortgage information. Different space types have context-specific details:

- **Streets:** Purchase price, color group, six rent tiers, development cost and ownership status.
- **Stations:** Rent based on the number owned.
- **Utilities:** Rent multiplier information.
- **Special squares:** Relevant contextual description.

### Full-screen gameplay

Open **Explore Board** from a running match for a larger presentation. The same center-dice interaction can be used there. Switch 2D/3D, navigate with pinch/drag, choose properties, review player cash cards and recent activity, and exit via the horizontal toolbar or app-bar Back action. Purchase/auction decisions open in bottom sheets when action is required; in full screen, a **compact app-bar control** can reopen a dismissed pending decision rather than showing a large duplicate action button above the board.

### Animated dice and glossy player-position effects

- **Dice:** Two Flutter-painted, glossy ivory dice tumble, bounce and briefly reveal multiple faces during a roll. After the roll, they settle into clean rounded faces without the earlier detached-looking top/right white extensions. The **engine/host** determines the result; rendering does not generate a new outcome.
- **Every player's position:** All active, non-bankrupt players receive a tile highlight based on their selected color. The currently acting player is emphasized; other occupied positions remain identifiable. Animated reflective sweeps and token halos improve visibility when the board is zoomed out.
- **Shared spaces:** A square occupied by multiple players displays a segmented/multicolored treatment, with separate token indicators.
- **Movement tracking:** The highlights follow presentation-level visible positions rather than teleporting immediately to the final board index.
- **Reduced Motion:** Animated pulsing and tumbling are reduced or stopped, leaving static readable markers. Turn this **off** in Game Experience if the expected animation seems absent.
- **Implementation distinction:** The live board uses Flutter drawing and 2.5D perspective, **not** a fully modeled GLB scene or a physics-based dice simulation. Five actual GLB models remain in the separate 3D Showroom.

### Top-layer game notices (Phases 13.10–13.12)

The app provides solid, high-contrast top notifications for warnings and confirmations. They are inserted in a root overlay layer above game content and modal sheets so the messages are not hidden behind the Android system bar or a purchase/auction dialog. Notices can be dismissed manually and also have a **five-second auto-dismiss timer**. The dismiss button uses semantics for accessibility without relying on a Tooltip requiring an unavailable ancestor Overlay.

The Phase **13.12** follow-up makes timer disposal lifecycle-aware. A widget test that displays a timed notice must dismiss it or dispose the notice overlay before test completion; otherwise Flutter's fake-async test framework reports pending timers. Notification timing and precedence still require Android/Web visual verification.

### Accessibility and rendering limits

Touch targets, text layout, screen-reader labels and reduced-motion behavior have been considered in individual updates. However, very small screens, large system-font scales, 300%+ board zoom, simultaneous notifications and long Bangla strings should still be manually tested on real devices.

---

## Languages, fonts, and currency

### Language support

The application provides **English** and **Bangla** interfaces. Localization resources reside in `lib/l10n/`. Language controls translated labels and numeral shaping; the **currency symbol is separately selectable** from the home settings menu. Some engine-generated activity strings remain English; monetary amounts in those messages are formatted at display time rather than changing saved or LAN records. The bank stock dialog uses **only the chosen language**, for example `Available houses: 32/32` or `অবশিষ্ট বাড়ি: ৩২/৩২`.

### Font configuration — current default

| Language | Default | Other registered choices / fallback |
| --- | --- | --- |
| **Bangla** | **Karnaphuli** | Nikosh fallback; Hadi and Nikosh selectable in Font Settings |
| **English** | **Exo2** | Roboto device option |
| **Logo / brand** | Exo2 | Brand identity remains consistent regardless of text preference |

Your current `pubspec.yaml` also declares **NikoshBAN**; its registration does not automatically mean it is listed in the selection catalog. Add selectable fonts to `lib/core/fonts/font_catalog.dart` as needed.

```yaml
flutter:
  fonts:
    - family: Exo2
      fonts:
        - asset: assets/fonts/Exo2-Thin.ttf
          weight: 100
        - asset: assets/fonts/Exo2-Light.ttf
          weight: 300
        - asset: assets/fonts/Exo2-Regular.ttf
          weight: 400
        - asset: assets/fonts/Exo2-Italic.ttf
          style: italic
        - asset: assets/fonts/Exo2-Bold.ttf
          weight: 700

    - family: Karnaphuli
      fonts:
        - asset: assets/fonts/KarnaphuliMJ.ttf

    - family: Hadi
      fonts:
        - asset: assets/fonts/Hadi.ttf

    - family: Nikosh
      fonts:
        - asset: assets/fonts/Nikosh.ttf

    - family: NikoshBAN
      fonts:
        - asset: assets/fonts/NikoshBAN.ttf
```

**Adding a font:** Copy a properly licensed, Unicode-capable `.ttf`/`.otf` to `assets/fonts/`, register it under the existing `flutter: fonts:` section, and add a `FontChoice` entry to `lib/core/fonts/font_catalog.dart`. Run `flutter pub get`, restart the app, and confirm rendering on Android and Web. **Do not add a second `flutter:` or `fonts:` top-level block.**

### Font Settings screen

Choose a Bangla and English font independently, preview sample/custom text, save the selection locally, or restore defaults. Your intended current Bangla default is **Karnaphuli → Nikosh fallback**. The `Hadi` family remains available as an alternative. Saved settings are device-local.

### Independent currency choice and money formatting (Phase 13)

Select **Currency → USD ($)** or **BDT (৳)** from the home-page hamburger menu. The currency setting is independent from the selected English/Bangla UI language:

| UI language | Currency selected | Example starting amount |
| --- | --- | --- |
| English | USD | `$1,500` |
| English | BDT | `৳1,500` |
| বাংলা | USD | `$১,৫০০` |
| বাংলা | BDT | `৳১,৫০০` |

The formatter uses Bangla digits when the locale is Bangla and supports South Asian grouping for larger values. Monetary amounts in property deeds, rent, purchases, auctions, recent events, and input prompts should use the selected display symbol. Dice values, player counts, tile indices and turn numbers are **not** currency amounts.

**Important:** This is a **display preference**, not a real-dollar-to-taka exchange-rate service. Switching from `$` to `৳` does not multiply or otherwise change any balances, rents, bids, taxes, or stored transactions. When a person has not selected a currency preference yet, the historical language-based defaults may apply.

---

## Profiles, tokens, and settings

### Player profile, avatars and color palette

- Set a local display name and avatar in the Profile screen. The color circle beside the name opens a **12-color palette**: **Amber, Sky, Rose, Mint, Lavender, Champagne, Teal, Apricot, Periwinkle, Lime, Orchid, Steel**.
- During local game setup, **a color cannot be assigned to more than one active seat**. Already-used colors are unavailable, and reserved colors can be reassigned when seats change. The palette choice persists locally.
- Player colors are reflected in cash cards, token markers, property ownership pennants, and the animated occupied-space highlight. They are serialized into new saved games and synchronized in host-controlled LAN snapshots.
- Choose among preset avatar/token styles and use stored profile photos where supported. In LAN play, sharing a personal profile photo is **opt-in**; supported images are resized/compressed toward a **64 KiB** transfer limit where possible.
- **LAN limitation:** The host's authoritative seat/color mapping synchronizes during a match, but independent guest profile color requests are not fully negotiated in the current LAN lobby.
- Profile photos and preferences are not account logins or proof of identity.

### Player token settings

The **Player Tokens** screen lets you choose a visual token for each seat and saves the selection on the device. Selected token icons are also used on the property owner pennants. Several tokens can be previewed using the packaged 3D models; the actual board displays optimized Flutter widgets instead of embedding a GLB WebView in every tile.

### Home page and Game Experience settings

The updated home page keeps the large **Start Game** button and dashboard cards, while secondary navigation lives in a **top-right hamburger menu**: language, currency, font settings, 3D showroom, player tokens, match history, and Game Experience.

- **Sound effects on/off** and volume slider. Phase 13 provides **seven original, gentle chime-style WAV effects** (dice, coin, purchase, build, jail, turn, victory). These are original synthesized sounds, **not Apple/iPhone sound files**.
- **Reduce Motion** stops or minimizes repeating dice/board effects while preserving actual game rules and positions.
- Camera choices for top-down, tabletop and cinematic board presentation.
- Android vibration/haptic feedback toggle (Web support depends on platform).
- Preferences persist locally between application launches.

### Bundled audio and GLB models

```text
assets/
├── audio/
│   ├── build.wav
│   ├── coin.wav
│   ├── dice_roll.wav
│   ├── jail.wav
│   ├── purchase.wav
│   ├── turn.wav
│   └── victory.wav
├── models/
│   ├── gold_car.glb
│   ├── pearl_dice.glb
│   ├── pearl_yacht.glb
│   ├── royal_crown.glb
│   └── sky_rocket.glb
├── fonts/                     # Font files registered in pubspec.yaml
└── icons/
    └── app_icon.png
```

Keep asset files in the project and register their directories in `pubspec.yaml`. Third-party fonts must only be redistributed when their licenses permit it.

---

## LAN multiplayer

The LAN architecture is **host-authoritative**: the guest sends action requests, the host checks whether each action is legal and who may perform it, and the host broadcasts the resulting state. The host remains the source of truth for dice, properties, auctions and cash.

### Platform roles

| Device/runtime | Host room | Join room | Automatic discovery |
| --- | --- | --- | --- |
| Android native | Yes | Yes | Best-effort UDP broadcast discovery |
| Native desktop build (when configured) | Intended/supported by native networking code | Yes | Best-effort UDP broadcast discovery |
| Flutter Web browser | **No** | Yes, using host IP and PIN | **No**; manual-IP join |

The project is primarily configured for **Android + Web**. A native desktop build also needs platform generation/configuration and testing; do not assume its installer is supplied.

### Network configuration

| Purpose | Transport / port |
| --- | --- |
| Game/lobby WebSocket | **TCP 8787** |
| Nearby-room announcements | **UDP 8788** |
| Room joining | Host device's local IPv4 address plus a **six-digit PIN** |
| Connection security | Local `ws://` (unencrypted) in the current implementation |

### Host a game

1. Connect players to the same trusted Wi-Fi network or hotspot.
2. On the native host: **Start Game → Wi-Fi/LAN Multiplayer → Host Game**.
3. Create a room and share its local IP and six-digit PIN with friends.
4. Let a second player join. The host starts the match when the minimum player count is met.
5. Continue gameplay; the host validates decisions and shares synchronized snapshots.

### Join a game

1. Open **Start Game → Wi-Fi/LAN Multiplayer → Join Game**.
2. Select a discovered nearby room on compatible native devices **or** enter the host IP manually.
3. Enter the correct PIN and join.
4. Once the host starts, the board displays the synchronized match state.

### LAN trading and reconnecting

- Propose a trade with eligible cash and property selections; the other player must **accept** before changes are applied.
- Buying, auction bidding, mortgage, building, and other actions are validated by the host.
- A joined guest that disconnects can retry reconnecting with its existing room/session token; Phase 11 added automatic retry intervals of **1, 2, 4, 8, and 12 seconds**, then manual retry.
- The host must remain running. There is **no automatic host migration** or cloud relay.
- Automated room discovery may be blocked by Wi-Fi client isolation, hotspot settings, firewalls, or UDP broadcast restrictions; **manual-IP joining remains the fallback**.
- Browser guests cannot generally connect to an insecure `ws://` host from an `https://` public site because of browser mixed-content rules; secure hosted multiplayer is a separate future task.

**Security:** Only host games on a network you trust. Do not port-forward **8787** or **8788** to the public internet. Do not share personal photos unless you intend other players on the room to receive them. For consistent LAN behavior, keep participants on the same compatible release (protocol **v3** in later phases).

---

## Saved games, history, and achievements

### Offline save and resume

- **Vs Computer** and **Pass & Play** automatically save after successful engine actions.
- A manual Save control is available.
- **Continue Saved Game** restores the local match, including balances, positions, properties, game phase, auctions, cards and relevant AI settings.
- One active offline match checkpoint is maintained per installation; starting another offline match can replace the previous one.
- Phase 12 added recovery from a **previous valid checkpoint** if the newest one is corrupted; the last move may be missing after recovery.
- Offline saves and backups live in device/browser-local storage (`shared_preferences`)—**not cloud storage**.

### Match history

- Completed offline matches are recorded locally, with winner, turn count and per-player results.
- Phase 10 added **completed LAN match history** when the device receives the final authoritative match state.
- Unfinished LAN matches do **not** use the offline save slot and are not resumable as an offline game.
- A guest that misses the final LAN state may not record that match.
- History contains a bounded set of recent completed games (up to **100** according to the Phase 9 store design) and can be deleted from the device.

### Statistics and achievements

The Match History screen includes **Overview**, **Matches**, and **Achievements**. Recorded statistics include matches played, wins/win rate, total turns, property-related measures and LAN/offline results. Achievement examples include:

- First Victory / Five Matches / Ten Victories.
- Property Collector / Property Magnate.
- Marathon / Endurance (turn-count milestones).
- First LAN Match / Five LAN Matches.

Achievements are computed from stored completed-match records, not a remote leaderboard. Clearing local data removes the history needed to recompute them.

---

## Technology stack

The entries below reflect the **user-supplied current `pubspec.yaml`**, rather than proposed upgrades.

| Component | Dependency / configuration |
| --- | --- |
| UI framework | Flutter (Material) |
| Language | Dart SDK `^3.11.0` |
| State management | `flutter_riverpod: ^2.6.1` |
| Local preferences / save | `shared_preferences: ^2.5.6` |
| Photos / camera or gallery | `image_picker: ^1.2.4` |
| File paths | `path_provider: ^2.1.6` |
| Localization | `flutter_localizations` (Flutter SDK), `intl: any` |
| Image manipulation | `image: 4.5.4` |
| LAN client sockets | `web_socket_channel: ^3.0.3` |
| Game audio | `audioplayers: 6.1.0` |
| 3D showroom | `model_viewer_plus: 1.10.0` |
| iOS-style icons | `cupertino_icons: ^1.0.8` |
| Testing | `flutter_test` (Flutter SDK) |
| Lints | `flutter_lints: ^6.0.0` |
| App icon generation | `flutter_launcher_icons: ^0.14.4` |

**Do not upgrade Riverpod 2 to 3 solely to silence dependency-outdated notices.** That major upgrade may need source migrations.

---

## Project architecture

The code separates UI, the mostly Flutter-independent rules engine, player/game data, AI, networking, persistence, and presentation configuration.

```text
bhive_monopoly/
├── android/                      # Native Android project, when generated
├── web/                          # Web entry point, manifest, app icons
├── assets/
│   ├── audio/
│   ├── fonts/
│   ├── icons/
│   └── models/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── fonts/
│   │   │   ├── font_catalog.dart
│   │   │   ├── font_preferences.dart
│   │   │   └── font_app_builder.dart
│   │   ├── theme/app_theme.dart
│   │   ├── ui/app_notices.dart      # Top-layer notification host and timer cleanup
│   │   └── utils/                 # Money formatting, currency preferences
│   ├── l10n/                     # app_en.arb, app_bn.arb, generated strings
│   ├── models/                   # App/profile data
│   ├── providers/                # Application state
│   ├── ui/screens/               # Home, Profile, Rules, Font Settings
│   └── game/
│       ├── core/board_data.dart
│       ├── models/game_models.dart
│       ├── engine/game_engine.dart
│       ├── ai/bot_controller.dart
│       ├── validation/game_snapshot_validator.dart
│       ├── network/              # Host, room, discovery, packets, trading
│       ├── persistence/          # Offline saves and match history
│       ├── experience/           # Audio, haptics, cameras, 12-color palette, settings
│       ├── presentation/         # Final standings data
│       └── ui/
│           ├── game_setup_screen.dart
│           ├── game_board_screen.dart
│           ├── lan_lobby_screen.dart
│           ├── lan_board_screen.dart
│           ├── board_explorer_screen.dart
│           ├── match_history_screen.dart
│           ├── token_settings_screen.dart
│           ├── three_d_showroom_screen.dart
│           ├── experience_settings_screen.dart
│           └── widgets/         # Board, dice, tokens, deed, sheets, HUD
├── test/
│   ├── fonts/
│   └── game/
├── tools/                        # Phase integration/release scripts
├── pubspec.yaml
└── README.md
```

### Design principles

- **Rules first:** `GameEngine` owns money, turn order, rent, and property transitions. UI does not directly set authoritative balances.
- **Local determinism:** The engine accepts actual dice values so test cases can reproduce outcomes.
- **Host authority on LAN:** Clients request actions; the host checks permissions and broadcasts the result.
- **Presentation-only localization:** Money symbols and some event strings are formatted without changing the underlying stored game state.
- **Backward-aware patches:** Saved games, fonts, avatars, and networking were extended incrementally; preserve user settings when integrating new files.

---

## Installation and configuration

### Prerequisites

- Flutter SDK compatible with **Dart `^3.11.0`**.
- Android SDK / a working Android emulator or device for Android.
- Google Chrome, Microsoft Edge, or a browser for Web testing.
- VS Code with Flutter and Dart extensions, or Android Studio.
- The font, audio, icon and GLB assets referenced by your `pubspec.yaml`.

### 1. Open your existing project

```powershell
cd F:\SKT_DATA\Personal\Study\Flutter\bhive_monopoly
flutter --version
flutter doctor -v
flutter devices
```

**This README assumes your working project has integrated Phases 2–13.12 in order.** Historical ZIPs were *incremental patches*, not entire Android/Web projects. The Phase 13.10 consolidated source archive is also **not** a complete independent Flutter checkout; retain your real `pubspec.yaml`, Android configuration, fonts, GLB models and assets. Avoid replacing newer corrected files with files from older phases.

### 2. Verify package identity

The first lines of `pubspec.yaml` should look like:

```yaml
name: monopoly
description: "A new Flutter project."
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ^3.11.0
```

Use imports like:

```dart
import 'package:monopoly/game/engine/game_engine.dart';
```

**Do not use** `package:bhive_monopoly/...` unless you intentionally rename the Dart package and update all imports. The Android application ID remains `com.bhive.monopoly`.

### 3. Verify assets

Your `pubspec.yaml` currently registers:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/audio/
    - assets/models/
    - assets/icons/app_icon.png
```

Also retain the font families in the [font configuration](#font-configuration--current-default) section. Ensure the exact referenced paths exist and are case-correct.

### 4. Resolve packages and run analysis

```powershell
flutter pub get
dart format lib test
flutter analyze
```

If you change fonts or add asset declarations, restart Flutter rather than relying only on Hot Reload. For stubborn asset caching problems:

```powershell
flutter clean
flutter pub get
```

### 5. Android networking configuration

When using LAN play, make sure the Android manifest contains the necessary permissions for network access and Wi-Fi state. The project has previously used:

- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- `android.permission.ACCESS_WIFI_STATE`
- `android.permission.CHANGE_WIFI_MULTICAST_STATE` where required by discovery

Camera/photo permissions depend on your installed `image_picker` behavior and Android API level; avoid adding unnecessary broad media access. **Local `ws://` connections and the 3D viewer's localhost WebView may require carefully scoped cleartext-network exceptions.** Do not expose LAN hosting on public networks.

---

## Run and build

### Run Android

```powershell
flutter devices
flutter run
```

If more than one device is connected, select an Android device ID from `flutter devices` and use `flutter run -d <device-id>`.

### Run Chrome with debugging

```powershell
flutter run -d chrome
```

For a PC that has trouble launching an automatic Chrome debugging profile, a fixed debugging port may help:

```powershell
flutter run -d chrome --web-browser-debug-port=9222
```

Close any *separate* Chrome debugging instance already using port 9222 before retrying.

### Run as a Web server (office PC: confirmed working port)

On the office PC used for this project, Windows rejects a TCP listener on port **8080** with error **10013**, although ports **18080**, **3000**, and an automatically chosen port were successfully bound during diagnosis. Run:

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=18080
```

Open **http://127.0.0.1:18080** manually in Chrome. This command was reported **working on the office PC**. It avoids Flutter automatically starting a Chrome debugging instance; browser debugging integration can differ from `flutter run -d chrome`.

You can separately try direct Chrome debugging with a fixed application/debugging port, provided those ports are free:

```powershell
flutter run -d chrome --web-port=18080 --web-browser-debug-port=9222
```

**Do not remove Windows reserved ports or disable managed office endpoint security to make the app start.**

### Release build outputs

```powershell
flutter build apk --release
flutter build appbundle --release
flutter build web --release
```

Typical output locations include:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
build/web/
```

Android production distribution requires **your own signing configuration**, appropriate versioning, privacy/store disclosures, and real device testing. Flutter Web output still needs an appropriate static host and browser verification. Hosting a public HTTPS Web client does **not** automatically make LAN `ws://` joining viable.

### Phase 12 release-check script

If it is present from the earlier patch:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\phase12_release_check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\phase12_release_check.ps1 -FullTests -BuildWeb
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\phase12_release_check.ps1 -FullTests -BuildAndroid
```

Review the script and its output locally; successful script invocation is not a substitute for multiplayer and device-level QA.

### Generate launcher icons

With the current `flutter_launcher_icons` setup:

```powershell
dart run flutter_launcher_icons
```

It uses `assets/icons/app_icon.png` for Android and Web output; iOS icon generation is currently disabled in the provided configuration.

---

## Testing and quality assurance

### Fast checks

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test test/game/
flutter test test/fonts/
```

To run the **Phase 13.12 notification timer regression** on its own:

```powershell
flutter test test/game/phase13_10_clean_dice_top_messages_test.dart
```

**If you have not installed the corresponding test patches, some test paths listed below may be absent.**

### Targeted regression checks

```powershell
# Game engine and bots
flutter test test/game/game_engine_test.dart
flutter test test/game/bot_controller_test.dart

# LAN protocol and host actions
flutter test test/game/lan_game_codec_test.dart
flutter test test/game/lan_action_dispatcher_test.dart
flutter test test/game/lan_loopback_integration_test.dart

# Assets, fonts and game presentation
flutter test test/game/phase8_models_assets_test.dart
flutter test test/game/game_typography_test.dart
flutter test test/game/phase12_1_responsive_board_test.dart
flutter test test/game/phase12_2_board_interactions_test.dart
flutter test test/game/phase12_3_owner_flags_zoom_toolbar_test.dart
flutter test test/game/phase12_4_money_symbols_test.dart
flutter test test/game/phase12_5_cash_activity_auction_ux_test.dart
flutter test test/game/phase12_5_board_center_overflow_test.dart
flutter test test/game/phase12_6_board_house_cash_exit_test.dart

# Phase 13 user experience, animated dice, glow, notices
flutter test test/game/phase13_player_color_currency_bot_dice_test.dart
flutter test test/game/phase13_3_modern_dice_test.dart
flutter test test/game/phase13_4_current_position_glow_test.dart
flutter test test/game/phase13_5_all_players_glow_rolling_dice_test.dart
flutter test test/game/phase13_10_clean_dice_top_messages_test.dart

# Game-state and save integrity
flutter test test/game/phase12_snapshot_integrity_test.dart
flutter test test/game/phase12_save_recovery_test.dart
flutter test test/game/phase12_lan_event_preflight_test.dart
```

Some test files were delivered in separate incremental ZIPs. If an individual file is absent from your checkout, verify that its corresponding phase/test patch was installed; otherwise run the complete folders that exist.

### Manual QA matrix

| Scenario | What to verify |
| --- | --- |
| 320–430dp Android portrait | No tile, dice, center HUD, cash card, or decision sheet overflows |
| Phone landscape / tablet / Web | Board, menus, sheets and buttons remain accessible without clipping |
| 2D / 3D | Switching works without losing game state or hiding board edges |
| Full-screen board | Dice, zoom/drag, property selection, cash cards and exit button work |
| Buildings | Buying a house/hotel adds a compact badge without `BOTTOM OVERFLOWED` warnings |
| Current cash | Updates after purchase, rent, bidding, building and mortgage changes |
| Ownership pennants | Correct owner color, player token symbol and inward direction on every board side |
| Currency | Independent USD/BDT selection works in both languages; messages and amounts use the chosen symbol, not exchange-rate conversion |
| Font settings | Karnaphuli default; alternate Hadi/Nikosh choices persist after restart |
| AI | Easy/Medium/Hard turns and auctions complete correctly |
| Save/resume | Exact state restored; backup recovery tests pass |
| LAN, 2+ devices | Same dice, position, property owners, money and turn phase across devices |
| Disconnect/reconnect | Guest returns to same identity without duplicate game actions |
| History & achievements | Completed offline/LAN match results recorded according to device receipt |
| Player positions | All active players have legible color-specific glow; two players on one tile remain distinguishable |
| Dice | Both dice tumble on roll, settle cleanly without stray top/right strips, and match engine output |
| Notices | Warning banners stay above open sheets, wrap at 320px, can be dismissed, and do not leave pending timers in widget tests |
| Reduce Motion | Animation reduction leaves static indicators and does not alter dice results or engine state |
| Showroom | All five GLB assets load and rotate on the supported runtime |

**Testing status (23 November 2026):** Flutter test output from the office PC has been used to correct several regressions in the explorer navigation, a duplicate "River Walk" finder, and continuously repeating animation tests. Phase 13.10–13.12 addressed a top-message Tooltip/Overlay assertion, a secondary Row overflow, and a **five-second pending Timer** in the narrow-screen widget test. **The user has not yet reported a final passing test run after applying Phase 13.12.** The documentation environment cannot run Flutter/Dart; verify `flutter analyze` and the complete game test suite locally before release.

---

## Troubleshooting

### `Target of URI doesn't exist: package:bhive_monopoly/...`

The actual package name is **`monopoly`**. Use `package:monopoly/...` in source and test imports, then run `flutter pub get` and restart VS Code's Dart analysis server if necessary. Do **not** add the app as its own dependency.

### `Unable to load asset: assets/models/gold_car.glb`

Check that the file exists and `assets/models/` is under the existing `flutter: assets:` list. Then run `flutter clean`, `flutter pub get`, and the Phase 8 model-assets test. Avoid duplicate YAML asset sections.

### Chrome fails to launch / `SocketException errno = 10013` on port 8080

On the office PC, `flutter run -d chrome` initially failed to launch, and `flutter run -d web-server --web-port=8080` failed to bind `127.0.0.1:8080`. A direct PowerShell TCP-listener test verified that **8080 was blocked** while **18080, 3000, and an automatically assigned port were available**. The IPv4 exclusion list did not list 8080, so the exact port-specific security/ownership cause was not conclusively established.

**Known-good office command:**

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=18080
```

Open `http://127.0.0.1:18080` in Chrome. If direct Chrome debugging is still desired, inspect the local browser debugging policy and firewall/endpoint protection rules with office IT; try `--web-port=18080 --web-browser-debug-port=9222` only when both ports are available. Do not change system-wide port exclusions without authorization.

### `pumpAndSettle` times out with continuously animated highlights

Phase 13.5 introduced repeating glossy position effects and token animations. Flutter's `pumpAndSettle()` may wait indefinitely for a frame-scheduled animation. In navigation widget tests, use **bounded `pump()` calls** and assert that the desired route or dialog is gone, rather than waiting for every animation in the app to stop. If the route does not disappear after bounded frames, inspect the actual Navigator callback; simply increasing the timeout is not a gameplay fix.

### Board explorer property finder matches twice

A property name such as `River Walk` appears both on the board and in the **All 40** list. `find.text('River Walk')` can match two widgets. Restrict the finder to the list row when testing list selection, for example `find.widgetWithText(ListTile, 'River Walk')`.

### `No Overlay widget found` while displaying a top notification

The top notification lives above the page Navigator, and the dismiss `IconButton` must not create a `Tooltip` that expects its own ancestor Overlay. Phase 13.11 removes that tooltip, retains `Semantics` for the accessible name, and fixes row wrapping. Do not revert to the old version of `lib/core/ui/app_notices.dart`.

### `A Timer is still pending even after the widget tree was disposed`

Top notices have a five-second dismiss timer. Phase 13.12 cancels this timer when the notice overlay is disposed and updates the narrow-width widget test to dismiss the notice explicitly. Run:

```powershell
flutter test test/game/phase13_10_clean_dice_top_messages_test.dart
```

If this still fails, confirm **both** the Phase 13.12 `app_notices.dart` and its matching test file were copied into your project; avoid mixing them with Phase 13.10/13.11 versions.

### RenderFlex overflow in the center board

Phase 12.5 introduced cash and activity UI under the dice, causing a fixed-height test overflow. Use the **Phase 12.5 Board Center Overflow Hotfix** and retain it when applying Phase 12.6. Verify both test viewport sizes and real-device landscape behavior. Avoid reapplying older `board_center_action.dart` files.

### `BOTTOM OVERFLOWED` in developed property tiles

Apply the **Phase 12.6** building overlay update; house/hotel indicators should not expand the small property tile's content height.

### Cash leader repeats the current balance

Phase 12.6 distinguishes **current cash** from the **cash advantage** when the current player leads. Otherwise it shows the actual other cash leader and that player's balance. Refresh the board state after actions; cash leader means **cash**, not total assets.

### Full-screen board cannot be exited conveniently

Phase 12.6 adds **Exit full screen** to the right of the Reset Zoom action in the horizontal toolbar. The app bar Back button remains available.

### Bangla font tests expect an old family

Current default is **Karnaphuli**, with Nikosh fallback. If a test expects `Hadi` or another earlier default, inspect the project's actual Font Settings defaults and update the *test expectation* only when the production configuration is correct. Do not hide real fallback-list errors by blindly changing assertions.

### LAN room not found

Connect to the same Wi-Fi/hotspot, ensure **TCP 8787** is reachable, and check client isolation, Windows/ESET firewall rules, and UDP **8788** broadcast. Try manual IP + PIN. Avoid public guest Wi-Fi networks that block device-to-device connections.

### `The named parameter ... isn't defined`

This can occur after mixing files from different phases. Verify that `AdaptiveBoardPanel`, `GameBoardView`, and related screen constructors belong to matching patch versions. In the Phase 12.2 hotfix, unsupported `diceValueProvider`/`isRollingProvider` arguments were removed from the `GameBoardView` constructor while the full-screen explorer retained its own provider callbacks.

---

## Development history

| Milestone | Main delivered change |
| --- | --- |
| **Phase 1** | Initial Flutter project, premium theme, home/profile foundations, language/fonts and branding |
| **Phase 2** | Playable 40-space Pass & Play game engine, rules, title/property actions |
| **Phase 3** | Easy/Medium/Hard computer players, animated dice and movement |
| **Phase 4** | Host-authoritative local Wi-Fi multiplayer, host/join, room PIN, reconnect identities |
| **Phase 4.1–4.2** | Bangla typography improvements and Hadi/Nikosh configuration (historical) |
| **Phase 5** | LAN property/cash trading, offline auto-save and Continue Saved Game |
| **Phase 5.1** | Persistent Bangla/English Font Settings page and live preview |
| **Phase 6** | Nearby LAN room discovery, avatars/photos, multi-property trading |
| **Phase 7** | Sound effects, volume/reduced-motion preferences, avatar compression |
| **Phase 8** | Five GLB assets, interactive 3D showroom, board camera presets, haptics |
| **Phase 9** | Player token customization, match history, achievements, victory confetti |
| **Phase 10** | Detailed property deeds, recent activity sheet, completed LAN match history |
| **Phase 11** | Smooth persistent token overlay, victory standings, automatic LAN reconnect attempts |
| **Phase 12** | Snapshot validation, offline previous-checkpoint recovery, release check script |
| **Font integration** | **Karnaphuli** became the default Bangla family; Hadi/Nikosh alternatives retained |
| **Phase 12.1** | Responsive 2D/2.5D board, full-screen explorer, zoom/pan, All 40 list |
| **Phase 12.2** | Single center dice control, inward owner markers, bottom-sheet decisions |
| **Phase 12.3** | Horizontal zoom toolbar; owner-colored token-icon triangular pennants |
| **Phase 12.4** | Currency symbols in recent events, activity, transactions and logs |
| **Phase 12.5** | Latest event below dice, cash leader/current cash HUD, auto-open decisions; overflow hotfix |
| **Phase 12.6** | Compact building overlays, cash-advantage display, full-screen exit control |
| **Phase 13** | Redesigned home/hamburger navigation; 12 exclusive seat colors; 20 random AI names; language-independent USD/BDT preference; 10% zoom; new audio, language-specific bank counts and 3D-style dice |
| **Phase 13.1** | Targeted fixes for 20 analyzer diagnostics (deprecated APIs, protected notifier usage, braces, imports, doc comments) |
| **Phase 13.2** | Removed redundant full-screen REVIEW DECISION/OPEN BID bars; pending decisions remain reopenable from a compact app-bar action |
| **Phase 13.3** | Porcelain dice styling: rounded ivory faces, dark pips and less exaggerated edges |
| **Phase 13.4** | Initial active-player position glow and glossy reflective sweep |
| **Phase 13.5** | Tumbling 3D-style dice and color-coded glossy occupied-tile highlights for **all** players, including shared squares |
| **Phase 13.6** | Cash-advantage regression correction and bounded-frame tests for continuous animation screens |
| **Phase 13.7** | Full-screen explorer exit navigation and test timing fix |
| **Phase 13.8** | Disambiguated River Walk list entry from the board's matching text in widget tests |
| **Phase 13.9** | Bounded explorer route-dismissal wait in navigation test |
| **Phase 13.10** | Clean settled dice rendering, stronger glossy effects, and a root-level high-contrast notification overlay |
| **Phase 13.11** | Fixed notification dismiss tooltip's missing Overlay assertion and narrow-screen Row overflow |
| **Phase 13.12** | Lifecycle-safe five-second notification timer cancellation and narrow-screen timer regression test |

**Integration rule:** Later patches build on earlier ones. Avoid overwriting a newer implementation with a file extracted from an older phase. Use Git to compare incremental updates.

---

## Known limitations and roadmap

### Current limitations

- **Not a final production release:** Full-device regression, package signing, privacy review, and multi-device soak tests remain necessary.
- **Board graphics:** The playable board is **2.5D**, not a fully integrated 3D scene; the GLB models currently live in the showroom/previews.
- **LAN:** Trusted local-network play only; no public matchmaking, encrypted internet relay, or host migration.
- **Web hosting:** Web clients join LAN hosts; browsers do not host the native LAN server. HTTPS/WSS interoperability needs separate design.
- **Persistence:** Offline saves and history are local to the device/browser and are lost when corresponding app data is deleted. Active LAN sessions do not have the same offline resume feature.
- **History:** Guests that miss the final state cannot reliably record a completed LAN match.
- **Localization:** Some engine-produced activity text remains English even though monetary amounts, the bank inventory dialog and many labels are localized. Currency selection is a display choice, not an exchange conversion.
- **Small displays:** Forty property tiles remain inherently dense on small phones; use zoom and the All 40 list for full details. Large zoom levels may crop the board until the view is panned or reset.
- **LAN player colors:** The host syncs a match color map; independent guest profile color selection is not negotiated during the LAN lobby.
- **Animations and accessibility:** Continuous effects can increase GPU/CPU work and complicate unbounded widget-test settling; use Reduced Motion where needed.
- **Notification test status:** Phase 13.12 timer-lifecycle fix is provided, but a final all-green full-suite result has not yet been supplied.

### Suggested future work

- Benchmarked, optional **GLB board tokens** with performance fallbacks.
- Further refinements for Bangla layout, long translated labels, consistent activity translation and large text-scale accessibility.
- UI performance profiling for 2D/3D dice, animated multi-player glow and notifications on lower-end Android devices.
- LAN lobby color preference negotiation for joining players without invalidating the host-authoritative seat palette.
- Full keyboard, screen-reader and semantic action audit.
- Expanded game-state fuzz testing and multi-device LAN recovery tests.
- Transaction replay/desync diagnostics and more comprehensive network resilience testing.
- Optional encrypted or internet-hosted multiplayer (as a separate architecture).
- User-friendly onboarding/tutorial and game help overlays.
- End-to-end Android/Web release pipeline, CI test automation and signed app-store distribution.

---

## Security, privacy, and publishing

**Device-local data:** Profile settings, font preferences, saved offline games, tokens and match history are persisted locally. The project source packages do not describe a cloud account or cloud sync service.

**Local LAN sharing:** During multiplayer, connected participants receive data needed to display game state, such as player names, tokens, balances, ownership, and game actions. Photo sharing is optional and should not be enabled on an untrusted network.

**Networking:** The current local multiplayer implementation uses **unencrypted WebSockets** on a local network. Do not present this as secure internet multiplayer and do not expose its host port publicly.

**App-store distribution:** Before publishing, supply accurate data-safety and privacy disclosures, review Android signing/versionCode, test all required screen sizes, and verify that all fonts, sounds, 3D models and imagery are owned or properly licensed for distribution.

**Branding and intellectual property:** This is an independently developed game using familiar property-trading mechanics and original property names. The term **Monopoly** may be protected as a brand/trademark in relevant markets. Review the product name, imagery, game-board presentation and any third-party rules/assets with appropriate legal advice before commercial publication. Do not claim official affiliation or endorsement.

---

## Contributing and license

The project is under active development. For changes, use a feature branch or commit a working baseline, run formatting/analyzer/tests, verify the impact on both offline and LAN rules, and review any schema/protocol changes before distributing a build to multiple players.

```powershell
git status
git add .
git commit -m "docs: update bHiVE Monopoly README through Phase 13.12"
```

**License:** No repository-wide source license has been specified in the provided project materials. Do not assume the code or bundled assets are open-source or redistributable until an explicit license and asset provenance are added.

---

**bHiVE Monopoly** · Flutter / Dart · Android + Web · English + বাংলা  
*Documentation baseline: Phase 13.12 · 23 November 2026*
