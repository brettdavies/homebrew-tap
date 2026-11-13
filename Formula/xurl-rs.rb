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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.0/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "72eb3dd5625a7a80ac0b537c167d4c1c04299adf6b07e878501ca2ec043b6305"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.0/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "d5bd716ff6e8d434cfd38d8e80cd531b6af37821fa30bf547a934bee45209f81"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.0/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "d789d120dbef03da25219b82aa688fb0885f065d5c34747ee1aebac8d3d8c961"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.7.0/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "59ec6ba69b50b01061b46f9ffbc674c500823a07e76b17c8a0078ddf084b9ebc"
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
