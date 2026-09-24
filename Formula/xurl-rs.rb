class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v4.1.1.tar.gz"
  sha256 "fde00649d5eec962b4fb8dd3784b28b146861f869b325f04a1631fcca063ebbe"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v4.1.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "d4fd4044ee1afc461ba0373a6b43001dc269ad9eab467abb7781989595a19df6"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "d45d9049c710a709eb5a809bd31d2806151c5f3bc1a65d12a26fa895ce62eba6"
    sha256 cellar: :any,                 arm64_linux:   "39ec26922f22a47028891b4615bb79a3c5a25e6ad5516e76f8a88de0976e8270"
    sha256 cellar: :any,                 x86_64_linux:  "e8a82080e39416e4b9277351a7f31fa175cbce59cd66ae9d2ef9dfdd4fe0a49f"
  end

  depends_on "rust" => :build

  def install
    # From 4.0.0 the tarball is a workspace whose root manifest is virtual and
    # the package that builds `xr` lives in crates/xurl-cli; earlier tarballs
    # are a single package at the root, which `cargo install` needs by path.
    path = File.directory?("crates/xurl-cli") ? "crates/xurl-cli" : "."
    system "cargo", "install", *std_cargo_args(path: path)
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
