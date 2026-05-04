class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.3.1.tar.gz"
  sha256 "74739dd42b6ddeac5e6706c379b4c0f80b262e7821c97225bc167ca8c4c1650e"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.3.1"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "9757186f979a4599ab4a4dae61348c110aaa8a79201ffdf0b9018b832eaf64d0"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "eba1fb7f25bdd89397b07e0b04bd0ba739ea517e34a3e89bf8a9817db9dd67f5"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "bcd2d9d2997a002e8c2701386c93ab068cfc7745eed9da57c2b0f29375810488"
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
