class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "ac44ea8632251fc7ac5d1c0f8d6c3400b7bce7b9d21af65ca30956917470ae95"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v1.1.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "5b34df6e15d68a1b221eb7230c71fd87673b7f80401c73ae152391012baeb02b"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "5cbd56f821f57d64ccc6352ea294f478ff12bfc8fcdb2e9424831739a7cf3e7d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "dfcb71b6a6f529bf4c0c9ba78419370151823797498e9da37e9c32b4e26b73dc"
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
