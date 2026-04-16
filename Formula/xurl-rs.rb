class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "64ceeee7bd47c7cdf7e9cca45fad999968b8d40166bbc61f69b580929824228c"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v1.2.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "517aa1a543bc0779eed86d592fd9ef09fe486b28bb47e3b545d80df20b0ece57"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "d6a5dbd93fba1f74a51ac83e1219fa5ffc27e06da62e49a850bb0f5df8ffa6c7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "602a69ee0ccb96bc8d69b4afafaf3deebcf076e0ca736f212df27bc3f613f88c"
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
