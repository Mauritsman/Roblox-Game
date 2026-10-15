# Logic (pure Luau)

Modules here are **pure**: no `game`, no `script`, no Roblox services, no `require` of other modules.
They get everything through arguments (numbers, tables, a seed) and return a result.
That means they can be tested without Studio using Lune: `lune run tests/run` (tests in `tests/**/*.spec.luau`).
Server and client code call them through `require(ReplicatedStorage.Shared.Logic.<Name>)`.
