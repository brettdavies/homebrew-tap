class Bird < Formula
  desc "X API CLI with entity caching, search, threads, and watchlists"
  homepage "https://github.com/brettdavies/bird"
  url "https://github.com/brettdavies/bird/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "8489081e3fbaf1c0b880ce6ba16005fab50b48fd90b59b72673662eef6824b0d"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/bird.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/homebrew-tap/releases/download/bird-0.1.2"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "84b6acc61feeee835e6e3cce5ac61ced71a6dde510e4d107f2e718f6805493dc"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "9b456cb3a0fe5bb060ac6a35b3e65a698d40894946d6f339700b172e43c13d19"
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
