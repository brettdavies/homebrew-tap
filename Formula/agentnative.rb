class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "a0e291dc750a8447f8f6a8846ed6c294667819d1c3e47a29ee72c18021f76db3"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.1.1"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "38ce79a62c6d9d5557bca59cd261ac51c346d3869f14bb5f2eff63d30359d002"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "87ab420cd0d53072b58eda25e8e6dbc60067304c896f1f73337ba5e8fc1ef8c0"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "92d61e8f40e111d129ba1796e27507e7c088dd862e62bd6f839a9321cd817a2d"
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
