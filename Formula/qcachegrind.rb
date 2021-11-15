class Qcachegrind < Formula
  desc "Visualize data generated by Cachegrind and Calltree"
  homepage "https://kcachegrind.github.io/"
  url "https://download.kde.org/stable/release-service/21.08.3/src/kcachegrind-21.08.3.tar.xz"
  sha256 "22e7991609f363cec8ff7b8631c4700fda391f5d6f9894b29727487d7c0915a1"
  license "GPL-2.0-or-later"

  # We don't match versions like 19.07.80 or 19.07.90 where the patch number
  # is 80+ (beta) or 90+ (RC), as these aren't stable releases.
  livecheck do
    url "https://download.kde.org/stable/release-service/"
    regex(%r{href=.*?v?(\d+\.\d+\.(?:(?![89]\d)\d+)(?:\.\d+)*)/?["' >]}i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_big_sur: "56367beb5e041fc7c212223572414a35913b61cab87cd4e40948f8c7a26b6631"
    sha256 cellar: :any,                 big_sur:       "b8b09416ce6dd7829da4c04044ed84dade46f3b652ff10bb9c1d2fab80a08691"
    sha256 cellar: :any,                 catalina:      "d6d92d76cb35a33f305e67810f5f6443c5cf1d56eab7e9de11d4f0df345141a2"
    sha256 cellar: :any,                 mojave:        "925fbdcc28c0b4f200414e3d957450619f9e1855ed87f60d2f56cd71fcded8d2"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "5015186bd3630d3dad1eca45438ceef8a7068327fa2405a8020a315f506916e0"
  end

  depends_on "graphviz"
  depends_on "qt@5"

  on_linux do
    depends_on "gcc"
  end

  fails_with gcc: "5"

  def install
    args = ["-config", "release", "-spec"]
    os = OS.mac? ? "macx" : OS.kernel_name.downcase
    compiler = ENV.compiler.to_s.start_with?("gcc") ? "g++" : ENV.compiler
    arch = Hardware::CPU.intel? ? "" : "-#{Hardware::CPU.arch}"
    args << "#{os}-#{compiler}#{arch}"

    system Formula["qt@5"].opt_bin/"qmake", *args
    system "make"

    if OS.mac?
      prefix.install "qcachegrind/qcachegrind.app"
      bin.install_symlink prefix/"qcachegrind.app/Contents/MacOS/qcachegrind"
    else
      bin.install "qcachegrind/qcachegrind"
    end
  end
end
