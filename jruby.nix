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
    outputHash = "1w4v0xfx3c5f1rn1gq28kk40j30fi3d9d5m15k7gzmvvm80hckhv";
  };
in stdenv.mkDerivation rec {
  pname = "jruby";

  version = "custom";

  src = jruby-src;

  buildInputs = [ makeWrapper maven ant jdk8 ];

  buildPhase = ''
    echo "Using repository ${maven-repository}"
    # We make sure to avoid installation since the maven repository is read-only now
    mvn -Dmaven.install.skip=true -Pdist --offline -Dmaven.repo.local=${maven-repository}

    mkdir ./dist
    tar -xzvf ./maven/jruby-dist/target/jruby-dist-*-bin.tar.gz --strip-components=1 -C ./dist
    cd ./dist
  '';

  # This is unmodified from  https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/interpreters/jruby/default.nix
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

  passthru = rec {
    rubyEngine = "jruby";
    gemPath = "lib/${rubyEngine}/gems/${rubyVersion.libDir}";
    libPath = "lib/${rubyEngine}/${rubyVersion.libDir}";
  };
}
