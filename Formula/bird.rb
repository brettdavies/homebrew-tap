class Bird < Formula
  desc "X API CLI with entity caching, search, threads, and watchlists"
  homepage "https://github.com/brettdavies/bird"
  url "https://github.com/brettdavies/bird/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "45bceeb04d47ab7337c95a2474cd0ffa902ebd360556435e38de8b5be06e89f4"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/bird.git", branch: "main"

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
