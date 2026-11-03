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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.2/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "988cdb2e15d4eb943e0a473d1681df4dcafd82dda29604d5437060eb5353e5f8"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.2/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "0dab5b65821a7dc88e1cb2926e0663d87bb056ec7757be40fd0d7a906f0e1f3a"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.2/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "04cfc5c24211d11ba07129811eed2d9d7a7a66603ca0623a066f3a9daa52c99e"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.2/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "47b6c4d3ea5c933948fe830eab78c0a585afcb98d37688852bb522b849a07acf"
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
