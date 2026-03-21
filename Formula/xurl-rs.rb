class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.0.5.tar.gz"
  sha256 "1e96410a612a51481121dfa573312c14bedea9279935ff8ef5aee455350e3e9c"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  # Bottles are hosted on the source repo release (brettdavies/xurl-rs)
  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"xr", "--generate-completion")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xr --version")
  end
end
