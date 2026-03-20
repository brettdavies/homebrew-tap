class Bird < Formula
  desc "X API CLI with entity caching, search, threads, and watchlists"
  homepage "https://github.com/brettdavies/bird"
  url "https://github.com/brettdavies/bird/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "8489081e3fbaf1c0b880ce6ba16005fab50b48fd90b59b72673662eef6824b0d"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/bird.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/bird/releases/download/v0.1.2"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "c8bcf6e80491503b03aaf9ca20f91f48e8ca3c861d3b200ab43f524b03e93d2a"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "ef4421cf23cb7c8275b70834b1f64f2ca926603c7a1ffa402b5d84fd16e12a06"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"bird", "completions")
  end

  def caveats
    <<~EOS
      bird requires xurl for X API authentication.
      Install it with:
        brew install xdevplatform/tap/xurl

      Verify your setup with:
        bird doctor
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bird --version")
  end
end
