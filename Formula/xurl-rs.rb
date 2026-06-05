class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "e86cff27ceca3ea50b16d672616d1fbbd794f7b8467bb23573668245f500cfe7"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v1.3.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "8df152930bb2dc5fcae2eb25508b3d13eb4fd5a7dcee952d8cfea357d0a44c41"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "0e10413168fceae4d3e4dd03abdfdd01ca2a3e3fbf64d15787aad31d22dd1814"
    sha256 cellar: :any,                 x86_64_linux:  "d9aefdc97b3b10b583d0b42d1903354a51de3748f3d43f024809f99b062c45c6"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    generate_completions_from_executable(bin/"xr", "completions")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xr --version")
  end
end
