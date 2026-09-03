class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v3.1.0.tar.gz"
  sha256 "ae02a2766ed22dcd6fe2a1aafa5d72cc50d4f3eb1a3f932f29ed102eb902a7de"
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
