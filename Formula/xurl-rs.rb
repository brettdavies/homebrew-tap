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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.1/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "7ea31c8f6a0cdd8b25bb6b4528543b51a7179eb85d37885f3845adc244d45044"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.1/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "d34186dde9edf57f7fd649d8af1815760d0b77f330fe2cde23ad42896c78dc26"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.1/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "f1100a3280249ee666dd4afd9989b673dc6a580831c62d7a4ac4fcbb597e8a8c"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.1/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "1bfc8153063d50a682e8250a7ec2f50a5e9f447af17f64c7bb6c11edd5359bde"
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
