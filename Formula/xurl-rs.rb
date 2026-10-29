class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  license any_of: ["MIT", "Apache-2.0"]

  head do
    url "https://github.com/brettdavies/xurl-rs.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.1/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "49a40f5c4720f0d50842ae3be4af206e6e0b0367cc0bcaf6f1fb9f5ac4a084da"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.1/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "267781c31db319c91aa8dc1c85b465fc1b45149d59dad404e9ec837f73409fc1"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.1/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "c7ca833f17f93f59e4709d64afc81fc82bc1c43061658fe86302ab612a5c2e67"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.1/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "eae7aac3216ec8da274ced261d1dc5fb19d5aa7e6436cce6dfa9a021edf6c7cb"
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
