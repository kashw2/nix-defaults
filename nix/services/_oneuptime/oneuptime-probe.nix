import ./workspace.nix {
  defaultPort = 3874;

  environment = name: {
    PROBE_KEY = "oneuptime-probe";
    PROBE_NAME = name;
  };
}
