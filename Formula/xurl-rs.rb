class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "e86cff27ceca3ea50b16d672616d1fbbd794f7b8467bb23573668245f500cfe7"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"xr", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xr --version")
  end
end
