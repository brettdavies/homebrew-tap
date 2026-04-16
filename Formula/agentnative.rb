class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://github.com/brettdavies/agentnative"
  url "https://github.com/brettdavies/agentnative/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "1c63f68bb35a256d2847fe540ce8c7ae361f40defe7bda0eb48af8cf173b9a1c"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"anc", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/anc --version")
  end
end
