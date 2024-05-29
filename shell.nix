with (import <nixpkgs> {});
let
  stdenv = pkgs.stdenv;
  gems = bundlerEnv {
    name = "trade-tariff-backend";
    ruby = ruby_3_2;
    gemdir = ./.;
  };
in stdenv.mkDerivation {
  LD_LIBRARY_PATH="${stdenv.cc.cc.lib}/lib/";
  name = "trade-tariff-backend";
  buildInputs = [
    bundix
    gems
    ruby_3_2
    postgresql
  ];
  shellInit = ''
  fish
  '';
}
