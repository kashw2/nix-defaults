{ lib, ... }:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Library functions exported by this flake, for use by other flakes.";
  };
}
