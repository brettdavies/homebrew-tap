class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "a0e291dc750a8447f8f6a8846ed6c294667819d1c3e47a29ee72c18021f76db3"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"anc", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/anc --version")
  end
end
