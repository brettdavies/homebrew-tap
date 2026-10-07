class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  license any_of: ["MIT", "Apache-2.0"]

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v4.2.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "40608e692a458e046fe2c023b892919064205a79785d53603a94bcf47cdfdc1b"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "58fcda0fa1bde5d445999f92eec733f20d8e1e99028c5d062113b6db4fc10d29"
    sha256 cellar: :any,                 arm64_linux:   "6193408d61b298f180581f17db1db6d8625725c0eb9bcff8e2de23409d144006"
    sha256 cellar: :any,                 x86_64_linux:  "e96f61360422a9b353d3e3ca69ddbcc9dc1a65c6eef9caca41d5dcbb816a1ad0"
  end

  head do
    url "https://github.com/brettdavies/xurl-rs.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.2.1/xurl-rs-aarch64-apple-darwin.tar.gz"
      sha256 "c725eab2dbf7f5788542ef9b44a837af3b9f1bcb554db0f8e9c84e4973609b46"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.2.1/xurl-rs-x86_64-apple-darwin.tar.gz"
      sha256 "bc96a1a44caeb61a96ed22518f68b768560757813683ae9f5b1587940ed3f370"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.2.1/xurl-rs-aarch64-unknown-linux-musl.tar.gz"
      sha256 "fd9c59a2cf83dad15bc88cfe02e81e72b237cdd4b361b759e371f4b2df9c8067"
    end
    on_intel do
      url "https://github.com/brettdavies/xurl-rs/releases/download/v4.2.1/xurl-rs-x86_64-unknown-linux-musl.tar.gz"
      sha256 "eb1eb7314071df43eb2e59ca1bcf968d74c1e410ee3b0b92488d85485278ac5a"
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
