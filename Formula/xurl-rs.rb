class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v2.1.0.tar.gz"
  sha256 "0fb025d3b5e3abe825c114ddada1aae12c50dc7694bdd7fa4239258df2da5ae9"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v2.1.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "853c134280908515e0629b9f2aa44081c6106d3a7845214f58688d2748e7159a"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "d6a186cf2c77a0bd609891852bd2392fc9870f32b224474e6ea282082d2bbcff"
    sha256 cellar: :any,                 x86_64_linux:  "7b80361b71614d9c12f5cff7a73a59b6584b28b6014b23c94cf18cd52971970a"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"xr", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xr --version")
  end
end
