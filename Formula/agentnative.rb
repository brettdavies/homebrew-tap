class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "4448097a6308f05b0886527a2f5c1be0db99afdc8ba42ce46908faffb954a26e"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.2.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "6ff0428b7414d91333ee2f0b2dda556f33fd9856ac4d17d61a86750995abdb6d"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "9c40868b4de144017a7387168015b0453e61d94c5fb55c8740e3d2d63f89e2fd"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "4cf8b6ddf6a71cedad379dfa9bd211d8b9962fcd724dca8563626308c8ba3f5d"
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
