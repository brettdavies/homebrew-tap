class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v3.2.0.tar.gz"
  sha256 "5eaebb0da4403495e96485fc68ba1c5750a545980694212ce8eed89550275a71"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v3.2.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "be6f1333068ee9152cab91625a8a849cd8fbb54d2cacf25c2ebae596afb89b12"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "de386762a65d1961671abe42fac64e98c66855deab763cd4dfa1d6a715b99d67"
    sha256 cellar: :any,                 arm64_linux:   "89414ada3b158e9a91769b0febc774aa85b5981dbf87c4f9a7269345c7805abd"
    sha256 cellar: :any,                 x86_64_linux:  "6a1bdba30db56861490726b84b7358ff7544ea5e28c424c63000ed7e66e6d7ed"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
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
