class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://github.com/brettdavies/agentnative"
  url "https://github.com/brettdavies/agentnative/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "1c63f68bb35a256d2847fe540ce8c7ae361f40defe7bda0eb48af8cf173b9a1c"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative/releases/download/v0.1.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "84cdcad018194e3d7cc04692b28816a5617bebb282eb5ad1d41416394ffb5dab"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "a2688075b8b785112f365ab5628c2d55923aa3a4ed188e68a2d7b0cf5557646e"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "20193fc599da25de2d6658c131d005a58bc8297c615281f7074e604fec0e3109"
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
