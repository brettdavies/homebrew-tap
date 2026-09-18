class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "c6c9ace8e92f1a8cbc89c7ae4aa21ffa5d7df00f6d05010c36b07af98185304e"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

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
