# Dig for Cash

A bright, tropical Roblox digging game. Core loop:
**DIG → FIND → COLLECT → RETURN → SELL → UPGRADE → DIG DEEPER**

The whole game (map included) is built from code with [Rojo](https://rojo.space).
Every push to `main` is checked and published to the Roblox place automatically.

## Status

**Phase 4 — Retention** done: rebirth (ranks, +25% cash each, shovel tints,
rebirth-only Secrets), playtime gifts, 7-day daily reward, daily Golden X,
Treasure Rush every 15 minutes, leaderboards (all-time and weekly), friends
bonus with an invite button, and a group reward (off until a group id is set).
Built on Phases 1–3: the core loop, the fun layer, and all four areas with
the collection.

## Layout

```
src/
  server/            ServerScriptService.Server (init.server.luau = bootstrap)
    Data/            SessionStore: session-locked DataStore profiles
    Services/        PlayerData, DigSpotService, DigService, LootService,
                     EconomyService, UpgradeService, AreaService,
                     CharacterService, Analytics
    World/           MapBuilder (builds the island), World (built-world holder)
    Net.luau         Remotes + per-player rate limiting
  client/            StarterPlayerScripts.Client (init.client.luau = bootstrap)
    Controllers/     HUD, digging, reveal, stations, guide arrow, gates, other players
  shared/            ReplicatedStorage.Shared
    Config/          ALL tuning numbers (odds, values, costs, timers, map layout)
    Logic/           Pure game rules (loot, progression, bag, save schema, zones)
    Builders/        Shovel and treasure models from primitive parts
    Util/            Format, RateLimiter, Signal
    AssetIds.luau    Every sound / animation id (placeholders marked TODO)
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
| `MapLayout.luau` | Island geography, base, stations, gates |

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
lune run scripts/pacing.luau              # pacing simulator
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

## Data

Profiles are saved with a session lock (`SessionStore`): a profile loaded in
one server can't be overwritten by another. Load failures kick the player with
a friendly message; a blank profile is never started over an unreadable save.
Schema changes go through `Logic/DataSchema.luau` (bump `CURRENT_VERSION`, add
a migration).
