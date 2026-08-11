{
  self,
  inputs,
  ...
}:

{
  flakes.nixosModules.default =
    {
      pkgs,
      lib,
      config,
    }:
    {

      imports = [ ];

    };
}
