_: {
  perSystem =
    { pkgs, self', ... }:
    {
      devShells.csharp = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [ self'.devShells.git-hooks ];
        packages = [
          pkgs.dotnet-sdk
          pkgs.dotnet-runtime
        ];
      };
    };
}
