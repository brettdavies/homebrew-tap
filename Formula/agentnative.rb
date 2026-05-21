class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.4.0.tar.gz"
  sha256 "ca7010839e62c67b26d6397a4f7129865073f08f5f576e30c70d2c3e6ff9fb38"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.4.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "284389cee70ca98e298ceee9691fe41c00085e2707e270bc0bbbb697cb8a57db"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "97404c3d9b5a4197deee406e320900f28c543727ec9097659b46edb2c299e95a"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "7ce4a418d7fa3cf4002b4d07f9813f5e1fbf96db674a2e81c5b8e13a18a4f656"
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
