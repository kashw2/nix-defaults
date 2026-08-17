{ self, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      self',
      ...
    }:
    {
      devShells.golang = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [ self'.devShells.base ];
        packages = [
          pkgs.go
        ];

        env = self.lib.mkOtelEnv pkgs.lib config.process-compose."default".services;
      };
    };
}
