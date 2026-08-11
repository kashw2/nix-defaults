_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.ansible = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [ self'.devShells.git-hooks ];
        packages = [
          pkgs.ansible
        ];
      };
    };
}
