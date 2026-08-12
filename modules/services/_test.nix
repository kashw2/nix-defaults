{ config, lib, ... }:
{
  settings.processes.test = {
    disabled = true;
    command = "true";
    depends_on =
      lib.genAttrs (lib.filter (n: n != "test") (lib.attrNames config.settings.processes))
        (_: {
          condition = "process_healthy";
        });
  };
}
