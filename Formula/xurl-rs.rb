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
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.0/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "9aaa0f2eba1491c46dd2e21351429c35643696f9b87d7238ebb2b982280543a7"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.0/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "31ca3e75ca9068575e1b2200ad1a237ba392d62c44f4218de8a4e6132bcc6468"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.0/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "91140f1291994cb19de06e352bbdcac16b9941fb51a22a555fef2a19aeedbe20"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.5.0/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "7cfc4c7ad1ff941a159065512254b219d296fdc4c8c837e4cb76287b9d6163e2"
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
