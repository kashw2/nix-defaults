import ./workspace.nix {
  defaultPort = 3876;

  environment = name: {
    ONEUPTIME_RUNNER_KEY = "oneuptime-runner";
    ONEUPTIME_RUNNER_NAME = name;
    ONEUPTIME_RUNNER_ENABLE_CODE_FIXES = "false";
  };
}
