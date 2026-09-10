class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v3.1.0.tar.gz"
  sha256 "ae02a2766ed22dcd6fe2a1aafa5d72cc50d4f3eb1a3f932f29ed102eb902a7de"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v3.1.0"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "25413d8b6f7d0f58ec26292efb428f87f8546bdf8096a7a083e9ba5ed8865839"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "9510322c377ab153951b4f6659b5f99bb35be2c0c5c4f2e93b6ba37822d79c43"
    sha256 cellar: :any,                 x86_64_linux:  "2fa8fc22691019b218d4c9a8f5eba3e2d58abff4c771f21abab4b0f70de75aac"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    bin.install_symlink bin/"xr" => "xurl-rs"
    generate_completions_from_executable(bin/"xr", "completions")
  end

  def caveats
    <<~EOS
      The command is `xr`. `xurl-rs` is linked as an alias so the formula
      name also runs; the documentation and shell completions use `xr`.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/xr --version")
    assert_match version.to_s, shell_output("#{bin}/xurl-rs --version")
  end
end
