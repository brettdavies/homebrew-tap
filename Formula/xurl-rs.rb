class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v2.2.0.tar.gz"
  sha256 "f262e7411d020df5b247b2446b48dd8a71a837acbde780d179da927c62c161b5"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v2.2.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "0e3de7e54265a6c4aa2afc9300a846b58b39af456404e0b60316ced662c4e014"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "5fe3ac56822d0d745eeeca9c42cf03654fb84ed448e2ccc6129df41fc9613d8f"
    sha256 cellar: :any,                 x86_64_linux:  "af7f1c5f3c4ad74b758c172a17a60acaac63dae4d5eeb0f6260d905d99d8ff43"
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
