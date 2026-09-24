class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v4.1.0.tar.gz"
  sha256 "92d944b1bbfe79f53baf8eb3c2970095718a4c91d0dac1ee3ea61bc13257bd50"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v4.1.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "20cdbe05f03a23507646dd7791789a36d6a1c689a9300292584a2b8e0a7b21fd"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "6d3762766610f5d76b2d24b7b44050c43686daf003a4468b1c08ac274885c1f4"
    sha256 cellar: :any,                 arm64_linux:   "3c3eed3802dd6c7a47819fbeebdfe1a632dee3c320edc6a7c612649e5865257f"
    sha256 cellar: :any,                 x86_64_linux:  "bf8d1dec813a9d3b900b13300e9541adb6b1ad4b92979f9fd69842886084164a"
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
