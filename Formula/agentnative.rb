class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.5.0.tar.gz"
  sha256 "0380f985a69b08e213efb6e36ef2e35ab82cc207a21469c78e4b3bec618df101"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.5.0"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "9947cf04aa24d04c92e222d059fa0919a7004ad204ccc77f039a33983189e92f"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "2ab6a1e2f5101d9c0c34c253abb445ff7094b294167301efdbe88f2c827ee87a"
    sha256 cellar: :any,                 x86_64_linux:  "6b5708a36c4372caa7dd9716b9b81cbb18cfc3150125b1b32f488da54b046071"
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
