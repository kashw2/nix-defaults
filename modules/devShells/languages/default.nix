_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.language-default = pkgs.mkShell {
        # Import every devShell we provide to consumers under `default`
        # There's an implicit contract here, the devShell must have the same attr name as it's filename
        # And cannot define more than one devShell for export
        inputsFrom = map (name: self'.devShells.${name}) (
          builtins.filter (n: n != "default") (
            map (
              v:
              builtins.substring 0
                # Strip the last four bytes for `.nix`
                (builtins.stringLength v - 4)
                v
            ) (builtins.attrNames (builtins.readDir ./.))
          )
        );
      };
    };
}
