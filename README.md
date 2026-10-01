# Dig for Cash

A bright, tropical Roblox digging game. Core loop:
**DIG → FIND → COLLECT → RETURN → SELL → UPGRADE → DIG DEEPER**

The whole game (map included) is built from code with [Rojo](https://rojo.space).
Every push to `main` is checked and published to the Roblox place automatically.

## Status

**Phase 5 — Monetization** done: a Shop with 7 game passes, 11 developer
products and shovel skins, contextual offers, and an idempotent receipt
handler (see Monetization below).

**Phase 4 — Retention** done: rebirth (ranks, +25% cash each, shovel tints,
rebirth-only Secrets), playtime gifts, 7-day daily reward, daily Golden X,
Treasure Rush every 15 minutes, leaderboards (all-time and weekly), friends
bonus with an invite button, and a group reward (off until a group id is set).
Built on Phases 1–3: the core loop, the fun layer, and all four areas with
the collection.

The island has three tiers: the Beach with the base plaza, a plateau split
into the Jungle and the Ancient Ruins by a rocky ridge, and the Volcano
highland under a huge volcano. Gates climb ramps through canyons in the
cliffs.

## Layout

```
src/
  server/            ServerScriptService.Server (init.server.luau = bootstrap)
    Data/            SessionStore: session-locked DataStore profiles
    Services/        PlayerData, DigSpotService, DigService, LootService,
                     EconomyService, UpgradeService, AreaService,
                     CharacterService, SettingsService, PurchaseService,
                     ServerBoostService, Analytics
    World/           MapBuilder (assembles the island), World (built-world holder)
      Build/         Terrain, Base, Gates, Beach, Jungle, Ruins, Volcano, Candidates, Kit
    Net.luau         Remotes + per-player rate limiting
  client/            StarterPlayerScripts.Client (init.client.luau = bootstrap)
    Controllers/     HUD, digging, reveal, stations, tutorial, gates, other players,
                     ambient life (birds, butterflies, crabs, fish, animated decor),
                     audio (music, area ambience, 3D loops), settings
    Sound.luau       Plays sound effects (variants, lead-in skip, pitch jitter)
  shared/            ReplicatedStorage.Shared
    Config/          ALL tuning numbers (odds, values, costs, timers, map layout)
    Logic/           Pure game rules (loot, progression, bag, save schema, zones)
    Builders/        Shovel and treasure models from primitive parts
    Util/            Format, RateLimiter, Signal
    AssetIds.luau    Every sound / animation id, with level and trim per clip
tests/               Offline tests for the pure logic (run with Lune)
scripts/             Pacing simulator, build verification
```

## Tuning

Every number lives in `src/shared/Config/`:

| File | What |
|---|---|
| `Treasures.luau` | Treasure list: rarity, home area, base value, model |
| `Areas.luau` | Area odds, unlock shovel, spot counts, `enabled` flag |
| `Upgrades.luau` | Shovel and bag ladders (cost, dig speed, capacity) |
| `Economy.luau` | Value variance, "Only $X to go!" threshold |
| `Loot.luau` | Clue chance and odds boost, mutations, dig streak, Deep Dig, first-find bonus, early guarantees |
| `Collection.luau` | Set bonus, set badges, announcement rules, trophy shelf slots |
| `Retention.luau` | Rebirth, gifts, daily calendar, Golden X, Treasure Rush, boosts, friends, group, leaderboards |
| `Dig.luau` | Dig ranges, respawn timers, anti-cheat tolerances |
| `MapLayout.luau` | Island geography, base, stations, gates, paths, landmarks |
| `Movement.luau` | Walk speed, spawn camera zoom |
| `Monetization.luau` | Passes, products, skins, perk numbers, offer limits |

To add a treasure: append a row in `Treasures.luau` (tests check its value band
and model archetype).

## Tooling

Pinned in `rokit.toml`: Rojo, Selene, StyLua, Lune.

```sh
rokit install
stylua --check src tests scripts          # format
selene src                                # lint
lune run tests/run.luau                   # tests (pure logic + config checks)
lune run tests/runtime/server_smoke.luau build.rbxl   # runs the real server headless
lune run tests/runtime/client_smoke.luau build.rbxl   # real client + server, DIG button to sale
lune run scripts/pacing.luau [runs] [pace]  # pacing simulator (pace 1.0 focused .. 2.0 slow)
lune run scripts/export-map.luau build.rbxl map.json && python3 scripts/render-map.py map.json out/
                                          # top-down map + view from the base (needs Pillow, numpy)
(cd scripts/preview && npm install) && node scripts/preview/render.mjs map.json out/
                                          # 3D views from the player's eye (three.js in headless Chromium)
lune run scripts/ui-snapshot.luau build.rbxl ui.json && node scripts/preview/render-ui.mjs ui.json out/
                                          # the real HUD and menus at phone size (fonts: scripts/preview/fonts/
                                          # LuckiestGuy.woff2 + FredokaOne.woff2 from Google Fonts, optional)
rojo build default.project.json -o build.rbxl
lune run scripts/verify-build.luau build.rbxl
```

## Publishing

`.github/workflows/publish.yml` runs on every push to `main` (and manually via
**Actions → Check and publish → Run workflow**):

1. Format check, lint, tests
2. `rojo build` → `build.rbxl`, then a structural check of the place
3. Publish with the Open Cloud Place Publishing API (universe and place ids in
   `deploy.config.json`, API key from the `DAT_PUBLISHING_KEY` secret)

If publishing returns 401/403: the key needs the `universe-places` **Write**
permission for this universe, and its IP allowlist must allow GitHub runners
(usually `0.0.0.0/0`).

**Before public launch:** switch live publishing to manual runs only (drop the
`push` trigger's publish step) so testing pushes can't change the live game.

## World building notes

Roblox draws terrain a few studs above a fill's top (voxels are 4 studs), so
the builders never trust fill heights for placement: props, the base deck,
gate ramps and dig spots all measure the real ground with raycasts
(`Kit.groundY`, `Kit.onLevel`, `Candidates.areaLevel`). Roblox also builds
terrain collision a moment after the voxels are written, so MapBuilder
waits for the terrain to answer raycasts (`Kit.waitForTerrain`) before
placing anything. The test harness copies both behaviors
(`Harness.terrainOffset`, `Harness.terrainSettle`), so code that trusts
fill heights or measures too early fails in CI. Roblox draws a Ball part with its smallest size axis,
so stretched round shapes use `Kit.ellipsoid` (a sphere mesh on a block).

## Audio

All audio comes from Roblox's own licensed Creator Store libraries (Pro Sound
Effects, APM Music, and the Roblox UI pack), so it is cleared for use in any
experience. `AssetIds.luau` lists each clip with a measured volume (so sounds
sit at an even level), a start offset (skips library lead-ins) and a length.
Digging uses a different set of hits per ground type (sand, jungle dirt,
volcanic rock). Fanfares briefly duck the music. Each area has its own
ambience bed, crossfaded as you walk, and the waterfall, campfire, lava and
crater have 3D loops. Players can turn Music and Sounds off in ⚙️ Settings
(saved in their profile).

## Monetization

Everything sold for Robux is listed in `src/shared/Config/Monetization.luau`
(name, description, price, icon, what it grants). The **Sync store** workflow
(Actions tab, manual) creates or updates every pass and product on Roblox from
that file through Open Cloud (`scripts/store-sync.luau`) and prints their ids
to paste back into the config. Icons live in `store/icons` (rendered by
`scripts/preview/render-icons.mjs`).

| Game pass | Robux | What it does |
|---|---|---|
| Auto Dig | 80 | Hold DIG to keep digging (on/off switch) |
| Treasure Radar | 99 | Arrow to the nearest clue spot (on/off switch) |
| +50% Bag | 149 | Bag holds 50% more |
| Auto Sell | 199 | Bag sells itself when full, anywhere, plus a SELL button (on/off switch) |
| 2x Dig Speed | 249 | Dig twice as fast (3x with a boost, max) |
| 2x Cash | 299 | Every sale x2 |
| VIP | 399 | Auto Dig + Auto Sell, +10% cash, gold name, [VIP] chat tag, VIP Gold shovel, VIP dig spot at the base |
| 2x Luck | 349 | **Off** (`enabled = false`); not created on Roblox until the developer decides |

Developer products: Starter Pack (49, one time), cash packs sized to the next
shovel (29 / 79 / 199), 15-minute 2x Cash and 2x Dig Speed boosts (49), a
server-wide 2x Cash for 10 minutes that thanks the buyer (199), Instant Deep
Dig (25), and shovel skins (99 / 149 / 199).

How purchases work:

* **One `ProcessReceipt` handler** (`PurchaseService`), idempotent: the grant
  and the receipt's `PurchaseId` are written to the profile together, the
  profile is saved, and only then is `PurchaseGranted` returned. A retried
  receipt is never granted twice; a player who isn't in the server, an
  unknown product or a failed save returns `NotProcessedYet`.
* **Passes** are checked on join (`UserOwnsGamePassAsync`) and granted at
  once on `PromptGamePassPurchaseFinished`; they're cached in the profile.
* **PolicyService** is read per player; 2x Luck (if ever enabled) never
  applies where paid random items are restricted.
* **Prompts open only on a tap** of a buy button. Contextual offers (holding
  DIG without Auto Dig, bag full far from base, Treasure Rush, a Deep Dig,
  the VIP spot) are small closeable bubbles, at most one every 3 minutes and
  never during the tutorial.
* The Shop shows the price Roblox reports for the player (price
  optimization), falling back to the config price.
* Analytics: `ShopOpened`, `OfferShown_<item>`, `PurchasePrompted_<item>`,
  `PurchaseCompleted_<item>` (custom events), cash packs as IAP economy events.

Not built yet: rewarded video ads (`ads.enabled = false`), the Treasure Club
subscription, and private servers (a Creator Hub setting).

## Data

Profiles are saved with a session lock (`SessionStore`): a profile loaded in
one server can't be overwritten by another. Load failures kick the player with
a friendly message; a blank profile is never started over an unreadable save.
Schema changes go through `Logic/DataSchema.luau` (bump `CURRENT_VERSION`, add
a migration).
