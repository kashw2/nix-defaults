_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.default = pkgs.mkShell {
        # Aggregate every sub-directory's top-level shell into `default`.
        # Each sub-directory exports a single shell named `<name>-default`
        inputsFrom =
          map (name: self'.devShells.${name}) (
            builtins.filter (pkgs.lib.hasSuffix "-default") (builtins.attrNames self'.devShells)
          )
          ++ [ self'.devShells.base ];
      };
    };
}
