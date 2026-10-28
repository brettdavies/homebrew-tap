class Agentnative < Formula
  desc "Linter that checks CLI tools for agent-readiness principles"
  homepage "https://anc.dev"
  license any_of: ["MIT", "Apache-2.0"]

  head do
    url "https://github.com/brettdavies/agentnative-cli.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    on_arm do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.7.0/agentnative-aarch64-apple-darwin.tar.gz"
      sha256 "4389502c353aeeaff1b8ea4e9896b094895e925a8860baa045736df90d16202d"
    end
    on_intel do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.7.0/agentnative-x86_64-apple-darwin.tar.gz"
      sha256 "c49f45497a3b0416cbb4c8ba0d20f5e209e41d2bb16cc57bf23584ca2de48467"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.7.0/agentnative-aarch64-unknown-linux-musl.tar.gz"
      sha256 "35ca0ab962a32d68bf9a08315b4ad8b0221c044bcef4ed53e06cd2698b519866"
    end
    on_intel do
      url "https://github.com/brettdavies/agentnative-cli/releases/download/v0.7.0/agentnative-x86_64-unknown-linux-musl.tar.gz"
      sha256 "fe63b306eb3ff8958d79976bfcb4e228793952d39a77ca393f9cf5e6cff667cd"
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
