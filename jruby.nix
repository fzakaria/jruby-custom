{ nixpkgs-src, ant, maven, jdk8, fetchFromGitHub, lib, stdenv, callPackage
, fetchurl, makeWrapper, jre }:

let
  # The version number here is whatever is reported by the RUBY_VERSION string
  rubyVersion = callPackage
    "${nixpkgs-src}/pkgs/development/interpreters/ruby/ruby-version.nix" { } "2"
    "5" "7" "";

  jruby-src = fetchFromGitHub {
    owner = "headius";
    repo = "jruby";
    rev = "51ba524444ffd23c4ba7f2b54c38915a965caf2c";
    sha256 = "0pj6hq6yi4jr2q54kw72jmpr9jlrzj89dkkm48gnwppnlbpbzjb7";
  };

  maven-repository = stdenv.mkDerivation {
    name = "jruby-maven-repository";
    buildInputs = [ jdk8 maven ];
    src = jruby-src;
    buildPhase = ''
      mkdir $out
      while mvn -Pdist -Dmaven.repo.local=$out -Dmaven.wagon.rto=5000; [ $? = 1 ]; do
        echo "timeout, restart maven to continue downloading"
      done
    '';
    # keep only *.{pom,jar,sha1,nbm} and delete all ephemeral files with lastModified timestamps inside
    installPhase = ''
      find $out -type f \
        -name \*.lastUpdated -or \
        -name resolver-status.properties -or \
        -name _remote.repositories \
        -delete
    '';
    # don't do any fixup
    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "07dim5xccbhg3r0abpv5xrd2xnkc5qciwvfc9sxpbj0wxgjdj69b";
  };
in stdenv.mkDerivation rec {
  pname = "jruby";

  version = "custom";

  src = jruby-src;

  buildInputs = [ makeWrapper maven ant jdk8 ];

  buildPhase = ''
    echo "Using repository ${maven-repository}"
    # 'maven.repo.local' must be writable so copy it out of nix store
    mvn -Pdist --offline -Dmaven.repo.local=${maven-repository}
  '';

  installPhase = ''
    mkdir -pv $out/docs
    mv * $out
    rm $out/bin/*.{bat,dll,exe,sh}
    mv $out/COPYING $out/LICENSE* $out/docs
    for i in $out/bin/jruby{,.bash}; do
      wrapProgram $i \
        --set JAVA_HOME ${jre}
    done
    ln -s $out/bin/jruby $out/bin/ruby
    # Bundler tries to create this directory
    mkdir -pv $out/${passthru.gemPath}
    mkdir -p $out/nix-support
    cat > $out/nix-support/setup-hook <<EOF
      addGemPath() {
        addToSearchPath GEM_PATH \$1/${passthru.gemPath}
      }
      addEnvHooks "$hostOffset" addGemPath
    EOF
  '';

  postFixup = ''
    PATH=$out/bin:$PATH patchShebangs $out/bin
  '';
}