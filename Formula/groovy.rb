class Groovy < Formula
  desc "Java-based scripting language"
  homepage "https://www.groovy-lang.org/"
  url "https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/apache-groovy-binary-4.0.4.zip"
  sha256 "3fd7f9f7c0e88ccd26c969e2f057dbede795dcb1f37b24caf6857bb5e8650ff1"
  license "Apache-2.0"

  livecheck do
    url "https://groovy.jfrog.io/artifactory/dist-release-local/groovy-zips/"
    regex(/href=.*?apache-groovy-binary[._-]v?(\d+(?:\.\d+)+)\.zip/i)
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_monterey: "7ed60f2c8d17f115eb1f9dfa4ebb502964410243d46fd1e06d3a771d7abffdac"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "310b9f07493cf28f5099e4f8411d756f52fbf0850800e17c140f189a8be36a6c"
    sha256 cellar: :any_skip_relocation, monterey:       "331dd6f98907bd6ce667e31162d70128c1c3d9ef11dbb1e1fd757af0417a78e0"
    sha256 cellar: :any_skip_relocation, big_sur:        "e2a4ebc31ada6ef901a678f68580cd34915fa7adca237166930a4c879e034e7a"
    sha256 cellar: :any_skip_relocation, catalina:       "37670753801d5add678f3682fbd6ea04b26aeafbefaf6afca3e88bfd3b4025ed"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "37b76fc2e835ca9359523d69be483a90414fc6e20f13ce4233310e30e5a1d532"
  end

  depends_on "openjdk"

  on_macos do
    # Temporary build dependencies for compiling jansi-native
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
    depends_on "maven" => :build

    # jansi-native is used to build native binary to support Apple Silicon.
    # Source version is from jline-2.14.6 -> jansi-1.12 -> jansi-native-1.6
    # TODO: Remove once updated to jline-3.x: https://issues.apache.org/jira/browse/GROOVY-8162
    resource "jansi-native" do
      url "https://github.com/fusesource/jansi-native/archive/refs/tags/jansi-native-1.6.tar.gz"
      sha256 "f4075ad012c9ed79eaa8d3240d869e10d94ca8b130f3e7dac2ba3978dce0fb21"

      # Update pom.xml to replace unsupported Java 6 source and to disable universal binary
      patch :DATA
    end
  end

  conflicts_with "groovysdk", because: "both install the same binaries"

  def install
    if OS.mac?
      jline_jar = buildpath/"lib/jline-2.14.6.jar"
      resource("jansi-native").stage do
        system "mvn", "-Dplatform=osx", "prepare-package"
        system "zip", "-d", jline_jar, "META-INF/native/*"
        system "jar", "-uvf", jline_jar,
                      "-C", "target/generated-sources/hawtjni/lib",
                      "META-INF/native/osx64/libjansi.jnilib"
      end
    end

    # Don't need Windows files.
    rm_f Dir["bin/*.bat"]

    libexec.install "bin", "conf", "lib"
    bin.install Dir["#{libexec}/bin/*"] - ["#{libexec}/bin/groovy.ico"]
    bin.env_script_all_files libexec/"bin", Language::Java.overridable_java_home_env
  end

  def caveats
    <<~EOS
      You should set GROOVY_HOME:
        export GROOVY_HOME=#{opt_libexec}
    EOS
  end

  test do
    output = shell_output("#{bin}/grape install org.activiti activiti-engine 5.16.4")
    assert_match "found org.activiti#activiti-engine;5.16.4", output
    assert_match "65536\n===> null\n", pipe_output("#{bin}/groovysh", "println 64*1024\n:exit\n")
  end
end

__END__
diff --git a/pom.xml b/pom.xml
index 369cc8c..6dbac6f 100644
--- a/pom.xml
+++ b/pom.xml
@@ -151,8 +151,8 @@
         <groupId>org.apache.maven.plugins</groupId>
         <artifactId>maven-compiler-plugin</artifactId>
         <configuration>
-          <source>1.5</source>
-          <target>1.5</target>
+          <source>1.7</source>
+          <target>1.7</target>
         </configuration>
       </plugin>
       
@@ -306,35 +306,5 @@
       </build>
     </profile>
     
-
-    <!-- Profile which enables Universal binaries on OS X -->
-    <profile>
-      <id>mac</id>
-      <activation>
-        <os><family>mac</family></os>
-      </activation>
-      <build>
-        <plugins>
-          <plugin>
-            <groupId>org.fusesource.hawtjni</groupId>
-            <artifactId>maven-hawtjni-plugin</artifactId>
-            <configuration>
-              <osgiPlatforms>
-                <osgiPlatform>osname=MacOS;processor=x86-64</osgiPlatform>
-                <osgiPlatform>osname=MacOS;processor=x86</osgiPlatform>
-                <osgiPlatform>osname=MacOS;processor=PowerPC</osgiPlatform>
-                <osgiPlatform>*</osgiPlatform>
-              </osgiPlatforms>
-              <configureArgs>
-                <arg>--with-universal</arg>
-              </configureArgs>
-              <platform>osx</platform>
-            </configuration>
-          </plugin>
-        </plugins>
-      </build>
-    </profile>
-    
-    
   </profiles>
 </project>
