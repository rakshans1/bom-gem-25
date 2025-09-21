{
  description = "Elixir Starter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
      };

      common = with pkgs; [
        # Elixir toolchain
        beam.packages.erlang_27.elixir_1_18

        # Tools needed in both CI and dev (used by justfile checks)
        just
        jq
        nodejs_22
        pnpm_9
        turbo
        biome
        shfmt
        shellcheck
      ];
      dev =
        if builtins.getEnv "CI" != "true"
        then
          with pkgs; [
            nixfmt-classic
            fswatch
            entr
            markdownlint-cli2
          ]
        else [];
      all = common ++ dev;

      inherit (pkgs) inotify-tools terminal-notifier;
      inherit (pkgs.lib) optionals;
      inherit (pkgs.stdenv) isDarwin isLinux;

      linuxDeps = optionals isLinux [inotify-tools];
      darwinDeps = optionals isDarwin [terminal-notifier];
    in {
      devShells = {
        default = pkgs.mkShell {
          packages = all ++ linuxDeps ++ darwinDeps;
          shellHook = ''
            mkdir -p .nix-mix .nix-hex
            export MIX_HOME=$PWD/.nix-mix
            export HEX_HOME=$PWD/.nix-hex
            export MIX_PATH="${pkgs.beam.packages.erlang_27.hex}/lib/erlang/lib/hex/ebin"
            mkdir -p .pnpm-store
            export PNPM_HOME=$PWD/.pnpm-store
            export PATH=${pkgs.erlang_27}/bin:$MIX_HOME/bin:$HEX_HOME/bin:$MIX_HOME/escripts:bin:$PNPM_HOME:$PATH
            export LANG=C.UTF-8
            # keep your shell history in iex
            export ERL_AFLAGS="-kernel shell_history enabled"

            export MIX_ENV=dev
          '';
        };
      };
    });
}
