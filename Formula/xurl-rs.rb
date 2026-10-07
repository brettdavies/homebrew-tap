class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  license any_of: ["MIT", "Apache-2.0"]

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v4.3.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "0ca67872468d100737495ee5f795d8fe506b26da9ed9ac2d30fa17a320488159"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "b4445d618f829411d20f60538fe46151e6fced9698e4ce6c23768d352432905b"
    sha256 cellar: :any_skip_relocation, arm64_linux:   "1ac902e4d7adfc54ae163dd1bcf212507294e0733a8ca4bd96d0ed354f23bbf0"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "0e9de5cef0eac085cb0f11b8991d3c6ba1381c91c82b28d81b8685cff2a3f9ed"
  end

  head do
    url "https://github.com/brettdavies/xurl-rs.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.3.0/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "4b1bb8c073f59d84054affc370c0702e9fa7cdc32374f2913bc6eae4e837af84"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.3.0/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "60d38e1d76012efbc545e7142d2123456ceaa141f09df9a0e303d02c5567142f"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.3.0/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "66575dd214ccd39e13655fb5b5ac00b03ee9129c29e5e94a21e1e1016325f65a"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.3.0/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "6abe6daf9806ca893c04e1ef206eaecc57316ab6aae1645a608b714822c994d1"
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
