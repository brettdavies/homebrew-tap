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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.0/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "ebe532dfa92ced09a502971c7cbd05087d071f76e3ca88adbfe56c4522a22ecc"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.0/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "b2973a53f5b4e7bdbe2db61c6b57cdf8aedfaaf36c2d949e44c22a943db6edd1"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.0/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "1875179e0598ee6528b269e21d8f0ff513d786649b48696389d5cd9130ccdbbc"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.0/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "9e4254bcb7ffdeb97f02f289c1bcce0d600fddf19eee6d72f16709efad75d3ca"
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
