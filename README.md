# Homebrew Tap

Homebrew formulae for brettdavies CLI tools.

## Usage

```bash
brew tap brettdavies/tap
brew trust --tap brettdavies/tap
```

The `brew trust` step is required when `HOMEBREW_REQUIRE_TAP_TRUST` is set (see
[Homebrew/brew#22470](https://github.com/Homebrew/brew/pull/22470)) and is expected to become the default in a future
Homebrew release. On older Homebrew versions that predate the `brew trust` command, the line is a no-op you can skip.

## Available Formulae

### xurl-rs

Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl.

```bash
brew install brettdavies/tap/xurl-rs
```

### bird

X API CLI with entity caching, search, threads, and watchlists.

```bash
brew install brettdavies/tap/bird
```

### agentnative

Linter that checks CLI tools for agent-readiness principles.

```bash
brew install brettdavies/tap/agentnative
```
