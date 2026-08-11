_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.nodejs = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [ self'.devShells.git-hooks ];
        packages = [
          pkgs.nodejs
        ];
      };
    };
}
