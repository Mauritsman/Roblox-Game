# Logic (pure Luau)

Modules hier zijn **puur**: geen `game`, geen `script`, geen Roblox-services, geen `require` van andere modules.
Ze krijgen alles via argumenten (getallen, tabellen, een seed) en geven een resultaat terug.
Daardoor kunnen ze zonder Studio getest worden met Lune: `lune run tests/run` (tests in `tests/**/*.spec.luau`).
Server- en clientcode roepen ze aan via `require(ReplicatedStorage.Shared.Logic.<Naam>)`.
