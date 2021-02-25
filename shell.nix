let
  nixpkgs-src = builtins.fetchTarball {
    name = "nixos-unstable-2020-11-30";
    url =
      "https://github.com/nixos/nixpkgs/archive/24eb3f87fc610f18de7076aee7c5a84ac5591e3e.tar.gz";
    sha256 = "1ca14hhbinnz1ylbqnhwinjdbm6nn859j4gmyamg2kr7jl6611s0";
  };
  nixpkgs = import (nixpkgs-src) {
    overlays = [
      (self: super: {
        jruby-custom = super.callPackage ./jruby.nix { inherit nixpkgs-src; };
      })
    ];
  };
in with nixpkgs;
with stdenv;
with stdenv.lib;
mkShell {
  name = "jruby-shell";
  buildInputs = [ jruby-custom ];
  shellHook = "";
}
