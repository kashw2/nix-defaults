{ config, lib, ... }:
{
  settings.processes.test = {
    disabled = true;
    command = "true";
    depends_on =
      lib.genAttrs (lib.filter (n: n != "test") (lib.attrNames config.settings.processes))
        (n: {
          condition =
            if (config.settings.processes.${n}.readiness_probe or null) != null then
              "process_healthy"
            else
              "process_completed_successfully";
        });
  };
}
