# Building purebred
#
# You should be able to simply invoke:
#
# $ nix-build
#
# or, to be explicit:
#
# $ nix-build default.nix
#
# in purebred's root directory in order to build purebred. You'll find the binary under:
#
# $ ls result/bin/purebred
#
# if the build was successful.
#
#
# Choosing a different compiler than the default
#
# In order to choose a different compiler, invoke nix build like so (escaping
# the quotes is needed, since we're passing a string literal):
#
# $ nix-build --arg compiler \"ghc442\"
#
#
# Build with purebred-icu
#
# $ nix-build --arg with-icu true
#
# Use as a development environment
#
# $ nix-shell default.nix
#
{ compiler ? null, nixpkgs ? null, with-icu ? false }:

with (import .nix/nixpkgs.nix { inherit compiler nixpkgs; });

let
  envPackages = self: if with-icu then [ self.purebred-icu ] else [ self.purebred ];
  icuPackageDep = hp: if with-icu then [ hp.purebred-icu ] else [];
  env = haskellPackages.ghcWithPackages envPackages;
  nativeBuildTools = with pkgs.haskellPackages; [
    cabal-install
    cabal2nix
    ghcid
    hlint
    haskell-language-server
    ormolu
    hie-bios
    pkgs.notmuch
    pkgs.tmux
    pkgs.gnumake
    pkgs.asciidoctor
    pkgs.python3Packages.pygments
  ];
in
    if pkgs.lib.inNixShell
    then haskellPackages.shellFor {
      withHoogle = true;
      packages = haskellPackages: [ haskellPackages.purebred ] ++ icuPackageDep haskellPackages;
      nativeBuildInputs = haskellPackages.purebred.env.nativeBuildInputs ++ nativeBuildTools;
    }
    else {
      purebred = pkgs.stdenv.mkDerivation {
        name = "purebred-with-packages-${env.version}";
        nativeBuildInputs = [ pkgs.makeWrapper ];
        # This creates a Bash script, which sets the GHC in order for dyre to be
        # able to build the config file.
        buildCommand = ''
          mkdir -p $out/bin
          makeWrapper ${env}/bin/purebred $out/bin/purebred \
          --set NIX_GHC "${env}/bin/ghc"
          makeWrapper ${env}/bin/purebred-dump-keybinding $out/bin/purebred-dump-keybinding \
          --set NIX_GHC "${env}/bin/ghc"
        '';
        preferLocalBuild = true;
        allowSubstitutes = false;
      };
    }
