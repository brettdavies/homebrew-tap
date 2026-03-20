class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.0.4.tar.gz"
  sha256 "a4007074c996eff466b0c822e39b374b2bf276e6bedf5cde3d6cc333819bfc24"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  # Bottles are hosted on the source repo release (brettdavies/xurl-rs)
  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"xr", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xr --version")
  end
end
