class Bird < Formula
  desc "X API CLI with entity caching, search, threads, and watchlists"
  homepage "https://github.com/brettdavies/bird"
  url "https://github.com/brettdavies/bird/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "9577cadddeec91f78ab5c036a9575ad6366ccfb1e6237aa71f7a33950d3ea283"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/bird.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/bird/releases/download/v0.1.1"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:  "0901757b469f94e3b1343e09d18930a7637806cf42a710c357eb6c2f91eee1c9"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "d38bd392826a6c29d7eec2f52b73503772b1301c6b190c9c9591dd10c3dfc8b3"
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
