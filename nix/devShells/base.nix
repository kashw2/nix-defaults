_: {
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    {
      devShells.base = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [ self'.devShells.git-hooks ];
        packages = [
          pkgs.git
          # Utilising `pkgs.nixVersions.latest` gets every consumer running the same version of nix in their projects
          # therefore removing one more source of drift for team member environments
          pkgs.nixVersions.latest
        ];
      };
    };
}
