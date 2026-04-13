class Bird < Formula
  desc "X API CLI with entity caching, search, threads, and watchlists"
  homepage "https://github.com/brettdavies/bird"
  url "https://github.com/brettdavies/bird/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "45bceeb04d47ab7337c95a2474cd0ffa902ebd360556435e38de8b5be06e89f4"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/bird.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/bird/releases/download/v0.1.3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "fe5b6ecaccd8205afccb595fa26bf18c0b441d64d10f9a7fef65e99e8681a232"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "fa44b05cce0df4b599976273203b0bed20105076214f975242db71e2718731ea"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "3591a507e9e06fa32f640fff1265be2088fdee51637459502c6712e1d588748d"
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
