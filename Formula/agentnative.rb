class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  url "https://github.com/brettdavies/agentnative-cli/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "4322173d4fe8da0c5bfce403d7240b024b26fc00e3b3f119ffb391952d2b91b7"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.1.2"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "e753bb1a309b391573749daa8e41487ae6dbfc4824a485a98f63e01d02e735b1"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "bdaade43317b519462cb716d49d37f2cd54611efa6d454e1668d3a4abc6bf59d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "4aa2d8483cd1f90d1760487596269ba38a2a60c3b571cb19b39a4870fc0b06af"
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
