{ config, lib, ... }:
{
  options.excludedTests = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "database:clickhouse" ];
    description = ''
      Processes the `test` process does not wait on. They still start, but
      their success or failure no longer decides whether the test passes.

      Exclusion is not transitive: naming a process here does not exclude the
      processes that depend on it, which keep gating the test as before.
    '';
  };

  config.settings.processes.test = {
    disabled = true;
    command = "true";
    depends_on =
      lib.genAttrs
        (lib.filter (n: n != "test" && !(lib.elem n config.excludedTests)) (
          lib.attrNames config.settings.processes
        ))
        (n: {
          condition =
            if (config.settings.processes.${n}.readiness_probe or null) != null then
              "process_healthy"
            else
              "process_completed_successfully";
        });
  };
}
