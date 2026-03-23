class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.0.5.tar.gz"
  sha256 "1e96410a612a51481121dfa573312c14bedea9279935ff8ef5aee455350e3e9c"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v1.0.5"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "f0200cb4d35732bca073809680993197a5edc83553aaec48ec4c93d09c5f3b80"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "bc68ff5b0da503723c479a03fc20d7234d2cbe420e5ee68b57d600c83f37708a"
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
