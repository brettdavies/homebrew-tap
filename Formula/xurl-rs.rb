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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.0/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "9e6bb1ba5bfca2d356c296040580dc23079ce43ac514e27ce7eee5a606fac498"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.0/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "65a385c77367c9968537ef42b241c8fbc7af9b248cd6864519814a613fd97a44"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.0/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "8bb4a8181805dc76bc71b7ec86ace44891737d1c361896009a6ce066f9d7a1be"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.4.0/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "e71cff49785b5a7218a74b6e9eea41bfb5ce22736cf0efc709b95eda23816e37"
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
