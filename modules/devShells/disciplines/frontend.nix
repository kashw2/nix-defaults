_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.frontend = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [
          self'.devShells.git-hooks
          self'.devShells.nodejs
        ];
      };
    };
}
