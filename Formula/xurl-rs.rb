class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v3.0.0.tar.gz"
  sha256 "e9551b622bccd64bf6af1a60a927f56071513f0fafac83057eaef76ac9fe75dd"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v3.0.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "10c85b24920d5b6771c5c1fb1fa955a191212578cf6a8b5fb98c59771761b8bd"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "7252743d93111bfeddbd57e6a7b05c2e38936bf123e6dab1ade9b67c52caca7f"
    sha256 cellar: :any,                 x86_64_linux:  "956045f472927c808bd6986cb9df98660b85c2d259f440503455133464fb3b61"
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
