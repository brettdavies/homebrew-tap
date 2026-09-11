class XurlRs < Formula
  desc "Fast, ergonomic CLI for the X (Twitter) API — the Rust port of xurl"
  homepage "https://github.com/brettdavies/xurl-rs"
  url "https://github.com/brettdavies/xurl-rs/archive/refs/tags/v3.1.0.tar.gz"
  sha256 "ae02a2766ed22dcd6fe2a1aafa5d72cc50d4f3eb1a3f932f29ed102eb902a7de"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/brettdavies/xurl-rs.git", branch: "main"

  bottle do
    root_url "https://github.com/brettdavies/xurl-rs/releases/download/v3.1.0"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "31d64632ee1b9d67e5015fff0cd8465deab86c14ec20cdf328b53c450dc1496a"
    sha256 cellar: :any_skip_relocation, arm64_sonoma:  "87a839edbb64f69509285a24eed53b9e1d840e15a42e697f9fb9206892649a0f"
    sha256 cellar: :any,                 x86_64_linux:  "161b4793608f2ac553cc739a33a3d2b7f91c10d9ce2993e7b9f45b742f186a12"
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
