_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.golang = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [ self'.devShells.base ];
        packages = [
          pkgs.go
        ];
      };
    };
}
