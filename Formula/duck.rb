class Duck < Formula
  desc "Command-line interface for Cyberduck (a multi-protocol file transfer tool)"
  homepage "https://duck.sh/"
  url "https://dist.duck.sh/duck-src-8.4.3.38269.tar.gz"
  sha256 "21d84f81080ff7a7b610b3705bd856de39f5de89c93a52b9df57c0a331f0f2ea"
  license "GPL-3.0-only"
  head "https://github.com/iterate-ch/cyberduck.git", branch: "master"

  livecheck do
    url "https://dist.duck.sh/"
    regex(/href=.*?duck-src[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 cellar: :any, arm64_monterey: "093827c8b48cf0e6ba73a5e7c92a417a9631b660d617e211f62067fe58f47ad0"
    sha256 cellar: :any, arm64_big_sur:  "0aaf91fcf727aabbd65182602adb2d57959f02f711b856c8582595166b9b134c"
    sha256 cellar: :any, monterey:       "f4970b4e6489604faeec05b969e33c34a46ad362dca96562ca691f465a292623"
    sha256 cellar: :any, big_sur:        "eb07b1c10d320ffa0a2ce8e4a14a09bf67dc658dec43715bf96b3bbcd3f8bca5"
    sha256 cellar: :any, catalina:       "95725862513b308dbb8709f68f8dc714f2a007175d0334d50443d8e2580eecf3"
    sha256               x86_64_linux:   "de597bdc5475ee71cd411b94ac42dfc4a460425d1cfec0864bed21d58f61bd0d"
  end

  depends_on "ant" => :build
  depends_on "maven" => :build
  depends_on "pkg-config" => :build
  depends_on xcode: :build

  depends_on "libffi"
  depends_on "openjdk"

  uses_from_macos "zlib"

  on_linux do
    depends_on "alsa-lib"
    depends_on "freetype"
    depends_on "libx11"
    depends_on "libxext"
    depends_on "libxi"
    depends_on "libxrender"
    depends_on "libxtst"

    ignore_missing_libraries "libjvm.so"
  end

  resource "jna" do
    url "https://github.com/java-native-access/jna/archive/refs/tags/5.11.0.tar.gz"
    sha256 "219086c61f804300871c2ec2ee220b6aac0fb8b6cbcc72dc53d4f35dc7f61fb6"
  end

  resource "rococoa" do
    url "https://github.com/iterate-ch/rococoa/archive/refs/tags/0.9.1.tar.gz"
    sha256 "62c3c36331846384aeadd6014c33a30ad0aaff7d121b775204dc65cb3f00f97b"
  end

  resource "JavaNativeFoundation" do
    url "https://github.com/apple/openjdk/archive/refs/tags/iTunesOpenJDK-1014.0.2.12.1.tar.gz"
    sha256 "e8556a73ea36c75953078dfc1bafc9960e64593bc01e733bc772d2e6b519fd4a"
  end

  def install
    # Consider creating a formula for this if other formulae need the same library
    resource("jna").stage do
      os = if OS.mac?
        # Add linker flags for libffi because Makefile call to pkg-config doesn't seem to work properly.
        inreplace "native/Makefile", "LIBS=", "LIBS=-L#{Formula["libffi"].opt_lib} -lffi"
        # Force shared library to have dylib extension on macOS instead of jnilib
        inreplace "native/Makefile",
                  "LIBRARY=$(BUILD)/$(LIBPFX)jnidispatch$(JNISFX)",
                  "LIBRARY=$(BUILD)/$(LIBPFX)jnidispatch$(LIBSFX)"

        "mac"
      else
        OS.kernel_name
      end

      # Don't include directory with JNA headers in zip archive.  If we don't do this, they will be deleted
      # and the zip archive has to be extracted to get them. TODO: ask upstream to provide an option to
      # disable the zip file generation entirely.
      inreplace "build.xml",
                "<zipfileset dir=\"build/headers\" prefix=\"build-package-${os.prefix}-${jni.version}/headers\" />",
                ""

      system "ant", "-Dbuild.os.name=#{os}",
                    "-Dbuild.os.arch=#{Hardware::CPU.arch}",
                    "-Ddynlink.native=true",
                    "-DCC=#{ENV.cc}",
                    "native-build-package"

      cd "build" do
        ENV.deparallelize
        ENV["JAVA_HOME"] = Language::Java.java_home(Formula["openjdk"].version.major.to_s)

        # Fix zip error on macOS because libjnidispatch.dylib is not in file list
        inreplace "build.sh", "libjnidispatch.so", "libjnidispatch.so libjnidispatch.dylib" if OS.mac?
        # Fix relative path in build script, which is designed to be run out extracted zip archive
        inreplace "build.sh", "cd native", "cd ../native"

        system "sh", "build.sh"
        buildpath.install shared_library("libjnidispatch")
      end
    end

    resource("JavaNativeFoundation").stage do
      next unless OS.mac?

      cd "apple/JavaNativeFoundation" do
        xcodebuild "VALID_ARCHS=#{Hardware::CPU.arch}", "-project", "JavaNativeFoundation.xcodeproj"
        buildpath.install "build/Release/JavaNativeFoundation.framework"
      end
    end

    resource("rococoa").stage do
      next unless OS.mac?

      cd "rococoa/rococoa-core" do
        xcodebuild "VALID_ARCHS=#{Hardware::CPU.arch}", "-project", "rococoa.xcodeproj"
        buildpath.install shared_library("build/Release/librococoa")
      end
    end

    os = if OS.mac?
      xcconfig = buildpath/"Overrides.xcconfig"
      xcconfig.write <<~EOS
        OTHER_LDFLAGS = -headerpad_max_install_names
        VALID_ARCHS=#{Hardware::CPU.arch}
      EOS
      ENV["XCODE_XCCONFIG_FILE"] = xcconfig

      "osx"
    else
      OS.kernel_name.downcase
    end

    revision = version.to_s.rpartition(".").last
    system "mvn", "-DskipTests", "-Dgit.commitsCount=#{revision}",
                  "--projects", "cli/#{os}", "--also-make", "verify"

    libdir, bindir = if OS.mac?
      %w[Contents/Frameworks Contents/MacOS]
    else
      %w[lib/app bin]
    end.map { |dir| libexec/dir }

    if OS.mac?
      libexec.install Dir["cli/osx/target/duck.bundle/*"]

      # Remove the `*.tbd` files. They're not needed, and they cause codesigning issues.
      buildpath.glob("JavaNativeFoundation.framework/**/JavaNativeFoundation.tbd").map(&:unlink)
      rm_rf libdir/"JavaNativeFoundation.framework"
      libdir.install buildpath/"JavaNativeFoundation.framework"

      rm libdir/shared_library("librococoa")
      libdir.install buildpath/shared_library("librococoa")

      # Replace runtime with already installed dependency
      rm_r libexec/"Contents/PlugIns/Runtime.jre"
      ln_s Formula["openjdk"].libexec/"openjdk.jdk", libexec/"Contents/PlugIns/Runtime.jre"
    else
      libexec.install Dir["cli/linux/target/release/duck/*"]
    end

    rm libdir/shared_library("libjnidispatch")
    libdir.install buildpath/shared_library("libjnidispatch")
    bin.install_symlink "#{bindir}/duck" => "duck"
  end

  test do
    system "#{bin}/duck", "--download", "https://ftp.gnu.org/gnu/wget/wget-1.19.4.tar.gz", testpath/"test"
    assert_equal (testpath/"test").sha256, "93fb96b0f48a20ff5be0d9d9d3c4a986b469cb853131f9d5fe4cc9cecbc8b5b5"
  end
end
