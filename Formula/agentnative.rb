class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "730d05bfed512b3e84accc8911180e65bba7df631810ddc571a61a617d2bbfcb"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.3.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "127bf0c409c97d5aad9bd659e5702cc30f64689b3e2da1d16394e6eeca07ba00"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "e01cd87d63a5f389e662723e956fcf04d73f73e9123316092b7469fc96781b22"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "057cb0ec18bf84a27021027fe2a412f027c449e86fd91cb962d2e287746b2aed"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"anc", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/anc --version")
  end
end
