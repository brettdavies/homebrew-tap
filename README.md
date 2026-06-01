# brettdavies/homebrew-tap

Homebrew formulae for [brettdavies](https://github.com/brettdavies) CLI tools. Each formula is built from its source
repo's tagged tarball; pre-compiled bottles are published for `ubuntu-22.04`, `macos-14`, and `macos-15` so the
common-platform install path is a download, not a source build.

## Setup

```bash
brew tap brettdavies/tap
brew trust --tap brettdavies/tap
```

### Why the `brew trust` line

Homebrew shipped tap-trust enforcement in [Homebrew/brew#22470](https://github.com/Homebrew/brew/pull/22470) (merged
2026-06-01) and the `brew trust` command in [Homebrew/brew#22472](https://github.com/Homebrew/brew/pull/22472). Today,
an untrusted third-party tap surfaces a `brew doctor` advisory warning. In a future Homebrew release
`HOMEBREW_REQUIRE_TAP_TRUST` becomes the default, and the warning is promoted to a load gate that prevents formulas from
this tap from installing.

Running `brew trust --tap brettdavies/tap` once tells Homebrew you've consciously chosen to trust formulas, casks, and
external commands from this tap. The decision is recorded in `$HOMEBREW_PREFIX/var/homebrew/trust.json` and persists
across `brew update`.

Notes:

- Official Homebrew taps (`homebrew/core`, `homebrew/cask`) are trusted automatically; this step is only for third-party
  taps like this one.
- If your Homebrew predates `brew trust` (anything before `5.1.14-141`), the command doesn't exist yet. You can either
  skip the line, or set `HOMEBREW_NO_REQUIRE_TAP_TRUST=1` in your shell profile to opt out of the future default.
- To revoke later: `brew untrust --tap brettdavies/tap`.

## Formulae

### `xurl-rs`

```bash
brew install brettdavies/tap/xurl-rs
```

Fast, ergonomic CLI for the X (Twitter) API. OAuth1, OAuth2 PKCE, Bearer auth, media upload, streaming, agent-native
output. Rust port of [xurl](https://github.com/xdevplatform/xurl) with shell completions and machine-readable output.

- Source: [brettdavies/xurl-rs](https://github.com/brettdavies/xurl-rs)
- License: MIT OR Apache-2.0
- Installs binary `xurl-rs`

### `bird`

```bash
brew install brettdavies/tap/bird
```

X API CLI built on `xurl` for authentication and transport. Adds a local entity store, watchlist monitoring, usage
tracking, thread reconstruction, and structured error output for agents.

- Source: [brettdavies/bird](https://github.com/brettdavies/bird)
- License: MIT OR Apache-2.0
- Installs binary `bird`

### `agentnative`

```bash
brew install brettdavies/tap/agentnative
```

The `anc` CLI: audits whether your CLI follows the agent-readiness principles defined at [anc.dev](https://anc.dev).
Self-dogfooding; the project's own score is the live `anc` badge on its docs site.

- Source: [brettdavies/agentnative-cli](https://github.com/brettdavies/agentnative-cli)
- License: MIT OR Apache-2.0
- Installs binary `anc`

## Keeping up to date

```bash
brew update
brew upgrade <formula>
```

Each formula tracks its source repo's latest tagged release. When upstream tags a new version, the source repo's
`release.yml` dispatches a formula bump into this tap. CI builds bottles for the three runner targets, and `brew
pr-pull` commits the bottle block onto `main`. From your machine, `brew upgrade <formula>` then downloads a ~3 MB bottle
instead of compiling from source (which would otherwise involve a temporary Rust toolchain install of ~470 MB).

## Troubleshooting

- **`brew doctor` says `brettdavies/tap` is not trusted** — run `brew trust --tap brettdavies/tap`. See
  [§ Why the brew trust line](#why-the-brew-trust-line).
- **`brew install` is compiling from source instead of pouring a bottle** — your platform isn't covered by the bottle
  matrix yet (currently `ubuntu-22.04`, `macos-14`, `macos-15`). Homebrew will install a temporary Rust toolchain,
  compile the formula, then clean up. Works on any platform Homebrew supports; just slower.
- **`brew install` fails partway through a source build** — usually means a Rust toolchain dependency couldn't install.
  Open an issue on the source repo (not this tap); the source repo owns the build configuration.
- **You want a specific older version** — pinned-version installs (`<formula>@<version>`) aren't published. Build from
  the source repo's tagged tarball, or `brew pin <formula>` after installing the current version to hold it at that
  version through `brew upgrade`.

## Distribution mechanics

This tap is the distribution layer for upstream brettdavies CLIs, not a vendored fork. Formulas live here; source code
lives in each CLI's own repo. Bottles are hosted on the source repo's GitHub Release assets (the formula's `bottle do`
block points back at the source), so the tap repo stays small and the source repo owns its own download surface.

The pipeline that connects an upstream tag to a published bottle, and the human dev-to-main flow that lands CI and
documentation changes here, are documented in [`RELEASES.md`](./RELEASES.md) and
[`RELEASES-RATIONALE.md`](./RELEASES-RATIONALE.md). Pre-release verification for the human path is in
[`RELEASES-PREFLIGHT.md`](./RELEASES-PREFLIGHT.md).

## Issues and contributions

- **Bug in a tool itself** (e.g. `xurl-rs` rejects valid input, `bird` returns wrong data, `anc` misclassifies a CLI):
  open an issue on the source repo linked above.
- **Bug in the formula** (formula audit fails, bottle missing for a supported platform, install hangs, trust step
  behaves unexpectedly): open an issue on [this tap](https://github.com/brettdavies/homebrew-tap/issues).
- **Want to add a new formula**: the tap is currently scoped to brettdavies's own CLI tools. PRs that update existing
  formulas or improve CI follow the flow in [`RELEASES.md`](./RELEASES.md): feature branch off `dev`, PR to `dev`, then
  promotion through a `release/*` branch to `main`.

## License

Each formula's underlying tool carries its own license (linked per-formula above). The formula files and CI in this tap
repo are de minimis metadata; no separate `LICENSE` ships in the tap repo.
