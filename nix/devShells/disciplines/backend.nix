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
      devShells.backend = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [
          self'.devShells.git-hooks
          self'.devShells.nodejs
          self'.devShells.csharp
        ];
        packages = [
        ];

        env = self.lib.mkOtelEnv pkgs.lib config.process-compose."default".services;
      };
    };
}
