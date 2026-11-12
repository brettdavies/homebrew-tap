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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.3/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "7c952c3904d2397a1b87521225820f949112f203ab599b7163c072e8681b8d50"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.3/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "7c9fccbee1a5cb4fe10274a119879aecf266f30494ad24323885cf94cad44767"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.3/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "cc057ba8439af147c26031467b2d6f0f67f8f955bb6149f87cb7f938074f5e74"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.6.3/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "41c659b200fd0b4308a01035fabf1607ea9a5ec6149f99c016085260f2d7f087"
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
