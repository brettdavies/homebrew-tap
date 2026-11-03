class Bird < Formula
  desc "X API CLI with entity caching, search, threads, and watchlists"
  homepage "https://github.com/brettdavies/bird"
  license any_of: ["MIT", "Apache-2.0"]

  bottle do
    root_url "https://github.com/brettdavies/bird/releases/download/v0.2.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "79c6dbf8d8eb11bb6a656436b7e2f77c2bcb6b1d53fbd94cce3b13abf8bd917a"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "9e62200af2d17f0180c66600e42ff997d4728e39ff616f03906ced4fbd2bc28f"
    sha256 cellar: :any,                 x86_64_linux:  "54dba2fa0fbc9e67bae5faf9f663e0e3b4ad4f206cc7156a8ef3fe64adde57a7"
  end

  head do
    url "https://github.com/brettdavies/bird.git", branch: "main"

    depends_on "rust" => :build
  end

  on_macos do
    depends_on macos: :sequoia

    on_arm do
      url "https://github.com/brettdavies/bird/releases/download/v0.2.0/bird-aarch64-apple-darwin.tar.gz"
      sha256 "a020059e4ce4780eebd8a118db8de54725ee6108429c015b5364a62a3142da57"
    end
    on_intel do
      url "https://github.com/brettdavies/bird/releases/download/v0.2.0/bird-x86_64-apple-darwin.tar.gz"
      sha256 "8520242d3ff0724a58b3bb2e608fcb1d460b314b61f51519297ea347653ee75a"
    end
  end

  # Static musl builds: they run against any glibc and link nothing from
  # Homebrew.
  on_linux do
    on_arm do
      url "https://github.com/brettdavies/bird/releases/download/v0.2.0/bird-aarch64-unknown-linux-musl.tar.gz"
      sha256 "a155b6f5db83654ac17a272ed522007d41841cfb6409404670e8e21e2be8117c"
    end
    on_intel do
      url "https://github.com/brettdavies/bird/releases/download/v0.2.0/bird-x86_64-unknown-linux-musl.tar.gz"
      sha256 "dc8a90d02cd5fcf897eed5cf50262b569f5ccbf14d394a95d6e1111fd0fe355f"
    end
  end

  def install
    if build.head?
      system "cargo", "install", *std_cargo_args
    else
      bin.install "bird"
    end
    generate_completions_from_executable(bin/"bird", "completions")
  end

  def caveats
    <<~EOS
      bird signs in and calls the X API through xurl-rs:
        brew install brettdavies/tap/xurl-rs

      Register your X API app with it, then sign in and check your setup:
        <secret-command> | xr auth apps add <name> --client-id <client id> --client-secret-file -
        bird login
        bird doctor

      bird also works with the Go xurl (brew install xdevplatform/tap/xurl).
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bird --version")
  end
end
