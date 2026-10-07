class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.6.0.tar.gz"
  sha256 "64e4369b0a4593026142034204068eb2ada59fd29dda50eb5b1f46d1cd56347a"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.6.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "27bf0712e29345661be44a12d99cf06cb3b2546b5446e0181d74ef8d5a8554b3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "ebe08f23b4e0f79e855e1f3a3b75bb311c0ca0833ef67c948f52a2280b446a39"
    sha256 cellar: :any,                 arm64_linux:   "9247b859b4f336c1b863bfd5ea211735233c65eb2a09dc2923fa863bdb1616aa"
    sha256 cellar: :any,                 x86_64_linux:  "dde4e50c80881b6cbdb75094a531023d762d387d76082d3a893a9807ec51c36c"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"anc", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/anc --version")
    assert_match "anc", shell_output("#{bin}/anc audit --help")
  end
end
