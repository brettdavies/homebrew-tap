class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v4.2.1.tar.gz"
  sha256 "880b5689cd328f3adf364a45a714032f1495cb59225adef338c03a63cce8f830"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v4.2.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "40608e692a458e046fe2c023b892919064205a79785d53603a94bcf47cdfdc1b"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "58fcda0fa1bde5d445999f92eec733f20d8e1e99028c5d062113b6db4fc10d29"
    sha256 cellar: :any,                 arm64_linux:   "6193408d61b298f180581f17db1db6d8625725c0eb9bcff8e2de23409d144006"
    sha256 cellar: :any,                 x86_64_linux:  "e96f61360422a9b353d3e3ca69ddbcc9dc1a65c6eef9caca41d5dcbb816a1ad0"
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
