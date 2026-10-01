{
  flake.lib.oneuptime = pkgs: rec {
    version = "14.0.10";

    src = pkgs.fetchFromGitHub {
      owner = "OneUptime";
      repo = "oneuptime";
      tag = version;
      hash = "sha256-AcbAL+jsYsEoSIcIcWU2xypWt232Fi/5+bVt0Unnojk=";
    };

    meta = {
      homepage = "https://oneuptime.com";
      changelog = "https://github.com/OneUptime/oneuptime/releases/tag/${version}";
      license = pkgs.lib.licenses.asl20;
      platforms = pkgs.lib.platforms.unix;
    };
  };
}
