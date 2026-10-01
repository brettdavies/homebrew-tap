class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v4.2.0.tar.gz"
  sha256 "347e2f47f4d95a4ad60c78ec9862e08d164326f79f4f84058230ee76393d7816"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v4.2.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "75f7afd3198754715ca8ae4eb0f3b5f773b06f8899d0c4eddda995959cc70a16"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "bd26d9b9debefabe51472606ef77ec4bcf0706d6c5617992b9b9db7c38be9370"
    sha256 cellar: :any,                 arm64_linux:   "e4f3b7891fc4af988da2ebbf6a09d1fb1f843a881be1a675bbc40263e2154ed4"
    sha256 cellar: :any,                 x86_64_linux:  "b6155274a1e6737e949bed4c9dc85961a2607ae27f8e35b986b8e51b10798e8a"
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
