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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.1/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "642a43f49f6bffc9a19e8b430eab6f775fa297d0e87f588a10765a67eda311d2"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.1/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "8e544bd633033da13bf1e6ca39046f3c288f01ec73647b42f09d94a1e0e08fe3"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.1/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "ea08255be00408854b59d243dbad18097dd938eb6b13d14f7b3224f2beab53e0"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.1/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "da8d34603aaa2b33225ede85c16d7772c72093bfd174b0768debb26c6afd684d"
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
