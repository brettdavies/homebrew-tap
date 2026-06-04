class Bird < Formula
  desc "X API CLI with entity caching, search, threads, and watchlists"
  homepage "https://github.com/brettdavies/bird"
  url "https://github.com/brettdavies/bird/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "af89a99acfa604b92e0ccef6857f5586f0c0885112138a94df0407187ed20b79"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/bird.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/bird/releases/download/v0.2.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "79c6dbf8d8eb11bb6a656436b7e2f77c2bcb6b1d53fbd94cce3b13abf8bd917a"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "9e62200af2d17f0180c66600e42ff997d4728e39ff616f03906ced4fbd2bc28f"
    sha256 cellar: :any,                 x86_64_linux:  "54dba2fa0fbc9e67bae5faf9f663e0e3b4ad4f206cc7156a8ef3fe64adde57a7"
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
