class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "3d743bbdf251c7ae0c9ed63b296cc995148205d80b016835c62dbb80edd694c0"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v2.0.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "dd1c40927ab5e3775f50f00107377e0f23dc9a8239eb7f0eeffafdaf0583ac99"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "4f08d8e29a5fe3319b819ccd9988e28a33b9d69f4749b9db3feeaaf13528f931"
    sha256 cellar: :any,                 x86_64_linux:  "d12ce28317f58aa451d6d6736245228dc63533345d7e94db94b7751c0d7684f0"
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
