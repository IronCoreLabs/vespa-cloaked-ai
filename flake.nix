{
  description = "Cloaked AI in Vespa example";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        # Builds run in Docker; this shell is for editing and building the plugin locally.
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bazel_8
            git
            openjdk25
            (maven.override { jdk_headless = openjdk25; })
            shellcheck
            vespa-cli
          ];
          JAVA_HOME = if pkgs.stdenv.hostPlatform.isDarwin then "${pkgs.openjdk25}" else "${pkgs.openjdk25}/lib/openjdk";
        };
      });
}
