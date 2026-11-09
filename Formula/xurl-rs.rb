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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.2/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "6868e996264e9672298dbdfe508c794512c9ae1771eb289e4bcfe5d40767ad7c"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.2/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "28645bf0d0a4027829e2e42db6531a40ffe5ea92c3f750804d597877afa3e8f7"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.2/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "97e40b037f1192dc767664454685b3207ff75954c36baadd678ce02b3f0d17e3"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.2/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "ed2dcc1ceb5b7ceafa2e059e55eff6cd573ae5a3c2b52348c4ea27754d57917b"
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
