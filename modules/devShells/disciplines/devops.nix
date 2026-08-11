_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.devops = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [
          self'.devShells.git-hooks
          self'.devShells.ansible
          self'.devShells.terraform
        ];
        packages = [
          pkgs.syft
          pkgs.grype
          pkgs.dive
          pkgs.awscli2
          pkgs.azure-cli
        ];
      };
    };
}
