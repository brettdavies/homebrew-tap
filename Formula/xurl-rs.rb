# Canonical version: 2026.11.03 (rust)
#
# The four archive names are what `update-formula.yml` reads to detect this
# form, download, verify, and re-pin on each release. Keep the `url` line
# directly above its `sha256` line.
#
# macOS 15 is the oldest macOS the tap supports, so `on_macos` opens by
# declaring it, in the formula form `:sequoia`. At the top level the same line
# would refuse every Linux install.
class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  license any_of: ["MIT", "Apache-2.0"]

  head do
    url "https://github.com/brettdavies/xurl-rs.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    depends_on macos: :sequoia
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.8.0/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "c4f3462370898080b9c725b9933cd511c745b735d0a2a54697e89d407861bebd"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.8.0/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "80fcbacc4f4cc02197bdd67cdeb03a3c0e79692115afba90bd21e662e622b826"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.8.0/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "d6cbb6034d8da54b4a3e76c8fec228c9a28ca39980e0af204aa2aeda8541bd10"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.8.0/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "acd32197a82c87cf55adc64257f059479265b8ae158f5517f8c20aee35049184"
    end
  end

  def install
    if build.head?
      system "cargo", "install", *std_cargo_args(path: "crates/xurl-cli")
    else
      bin.install "xr"
    end
    bin.install_symlink bin/"xr" => "xurl-rs"
    generate_completions_from_executable(bin/"xr", "completions")
  end

  def caveats
    <<~EOS
      The command is `xr`. `xurl-rs` is linked as an alias so the formula
      name also runs; the documentation and shell completions use `xr`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xr --version")
    assert_match version.to_s, shell_output("#{bin}/xurl-rs --version")
  end
end
