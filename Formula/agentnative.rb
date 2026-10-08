class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  license any_of: ["MIT", "Apache-2.0"]

  bottle do
    root_url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.6.0"
    sha256 cellar: :any_skip_relocation, arm64_tahoe:   "27bf0712e29345661be44a12d99cf06cb3b2546b5446e0181d74ef8d5a8554b3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "ebe08f23b4e0f79e855e1f3a3b75bb311c0ca0833ef67c948f52a2280b446a39"
    sha256 cellar: :any,                 arm64_linux:   "9247b859b4f336c1b863bfd5ea211735233c65eb2a09dc2923fa863bdb1616aa"
    sha256 cellar: :any,                 x86_64_linux:  "dde4e50c80881b6cbdb75094a531023d762d387d76082d3a893a9807ec51c36c"
  end

  head do
    url "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    on_arm do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.6.0/agentnative-aarch64-apple-darwin.tar.gz"
      sha256 "a079bc6e095d4a33c895cfc9c41f58b9d8a9fdd4eba24ad6a6aac00902d912f5"
    end
    on_intel do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.6.0/agentnative-x86_64-apple-darwin.tar.gz"
      sha256 "48110ac47770694008133272130a840e73752fa7e4eb32a31066300b2d44ac88"
    end
  end

  # Static musl builds; they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.6.0/agentnative-aarch64-unknown-linux-musl.tar.gz"
      sha256 "9824f6a8c251e43fbc2f4281f6a31298c324460047ba290e3950b736e90f65d1"
    end
    on_intel do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.6.0/agentnative-x86_64-unknown-linux-musl.tar.gz"
      sha256 "4dd0caf80fc63eface04747e9b0fc34a0037f8805f7c6decdc65c2ce094e3c13"
    end
  end

  def install
    if build.head?
      system "cargo", "install", *std_cargo_args
    else
      bin.install "anc"
    end
    generate_completions_from_executable(bin/"anc", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/anc --version")
    assert_match "anc", shell_output("#{bin}/anc audit --help")
  end
end
