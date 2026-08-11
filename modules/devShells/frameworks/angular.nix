_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.angular = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [
          self'.devShells.git-hooks
          self'.devShells.nodejs
        ];
        packages = [
          pkgs.prettier
        ];
      };
    };
}
