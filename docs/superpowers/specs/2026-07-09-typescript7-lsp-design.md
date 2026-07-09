# TypeScript 7 LSP Migration Design

**Date:** 2026-07-09
**Status:** Approved

## Background

TypeScript 7.0.2 (released 2026-07-08) is the Go-native rewrite of the compiler
([announcement](https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/)).
`tsserver` no longer exists; TS7 ships a native LSP server embedded in the
compiler binary.

Verified facts (checked 2026-07-09):

- `typescript@7.0.2` (npm `latest`) ships a single binary, `tsc`. It serves LSP
  via `tsc --lsp --stdio` (handshake verified locally against a real
  `initialize` request).
- `@typescript/native-preview` (nightlies) still ships the binary under the old
  `tsgo` name.
- Mason registry package `tsgo` installs the native-preview nightly and puts
  `tsgo` on PATH. It maps to nvim-lspconfig's `tsgo` server config.
- nvim-lspconfig's stock `lsp/tsgo.lua` (installed and master) runs
  `tsgo --lsp --stdio`, preferring project-local `node_modules/.bin/tsgo` — a
  binary stable TS7 projects do not have (renamed to `tsc`).
- `typescript-language-server` (`ts_ls`) is an LSP→tsserver translation shim.
  It cannot serve TS7 (no tsserver to wrap). It still works for TS ≤ 6.

## Decisions

- **All-in on TS7** (user): older-project fidelity is not a priority.
- **Replace `ts_ls` with `tsgo`** — no dual-server routing. Both claim the same
  filetypes; enabling both would attach duplicate clients (same problem class
  as the rust-analyzer quirk in CLAUDE.md).
- **JS diagnostics enabled everywhere** (user): the old on_attach hack that
  disabled diagnostics for `javascript`/`javascriptreact` buffers is deleted,
  not migrated.
- **Local-first cmd resolution** (approach B): prefer the project's own stable
  compiler so editor diagnostics match the project's `tsc` exactly; fall back
  to Mason's nightly for scratch files.

## Changes

### `lua/plugins/lsp-config.lua` (only code change)

- Replace the `vim.lsp.config.ts_ls` block with `vim.lsp.config.tsgo`
  (capabilities like the other servers; no on_attach).
- Swap `"ts_ls"` → `"tsgo"` in `vim.lsp.enable({...})`.
- Custom `cmd` resolver (~15 lines), evaluated per project root:
  1. `node_modules/typescript/package.json` major ≥ 7 **and**
     `node_modules/.bin/tsc` executable → run
     `<root>/node_modules/.bin/tsc --lsp --stdio`.
  2. Else `node_modules/.bin/tsgo` executable (local preview install) → use it.
  3. Else global `tsgo` (Mason bin on PATH).
  Any read/parse failure falls through to the next step; never a hard error.
- Everything else is inherited from nvim-lspconfig's stock `lsp/tsgo.lua` via
  config merging: lock-file root detection, Deno-project avoidance, inlay-hint
  settings (inert — inlay hints are not enabled in this config).

No new plugins. `lazy-lock.json` untouched.

### Installation (per-machine, like codelldb)

- `:MasonInstall tsgo`
- Uninstall `typescript-language-server` from Mason so it cannot be
  auto-enabled.
- During implementation, verify the installed mason-lspconfig version's
  auto-enable behavior does not resurrect `ts_ls`.

### CLAUDE.md

- Language Servers list: replace the `ts_ls` line with `tsgo` (TS7 native LSP,
  local-first resolution, JS diagnostics now enabled).
- Known Quirks: add the per-machine `:MasonInstall tsgo` note and the
  stable-vs-nightly binary naming (`tsc` in `typescript@7`, `tsgo` in
  native-preview/Mason).

## Behavior changes

- JS files gain diagnostics.
- TS 5/6 projects are served by the Mason nightly with TS7 semantics.
  Escape hatch if one misbehaves: `npm i -D @typescript/native-preview` in that
  project (resolver step 2 picks it up).
- Hover, keymaps, float styling, and none-ls/prettier formatting are untouched.

## Out of scope

- Vue/Svelte/Astro/MDX embedded-language workflows (Microsoft advises TS 6.x
  there; not part of this config's use).
- Inlay hint enablement, hover changes, or any keymap changes.

## Verification plan

Test bed: a throwaway project with a lockfile and `typescript@7` installed
(`npm init -y && npm i -D typescript@7`).

1. TS7 project: `tsgo` client attaches; cmd is the project-local
   `node_modules/.bin/tsc --lsp --stdio`.
2. Bare `.ts` file outside any project: `tsgo` attaches via global Mason
   binary.
3. JS file: diagnostics appear.
4. `ts_ls` attaches nowhere; exactly one TS client per buffer.

Method: headless `nvim` checks where scriptable; interactive user confirmation
for the rest.
