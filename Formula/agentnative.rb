class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "c638884ba87ea0b05efe586476ab506ad1214514ca81b99323d01c7091a8612f"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.1.3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "098954be98dea0a811ebd366f12dc15ce683c74da180ed7e66fb5897748555e7"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "6ddabdcdf5ff82e72505edf6ac674d4f8302c1375472990391cee460255dc159"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "3597cc83e1917f4904554d1ec2bf68af3e42edcf2f296c0958847a2883178522"
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
