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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.1/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "b697e60b71dc879034b74aec92591365945935ff19756e37e63243d90a5f2379"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.1/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "77e5ba00be5efd84474dec40669c6698dfdbadc999093756c1d60d0563c4a60a"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.1/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "6b1971e2bbc6ae0aac6c3c9cbc603182c622a77d3fec8e56f17e1b39f47090e5"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.1/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "392cb04583dfd33f3e84fba386db3a0086bab890a099068314152847f9dee1c2"
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
