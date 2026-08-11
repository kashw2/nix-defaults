{ inputs, ... }:
let
  treefmt = {
    imports = [
      inputs.treefmt-nix.flakeModule
    ];

    perSystem = { ... }: {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.deadnix.enable = true;
        programs.actionlint.enable = true;
        programs.dockerfmt.enable = true;
        programs.gofmt.enable = true;
        programs.jsonfmt.enable = true;
        programs.terraform.enable = true;
        programs.d2.enable = true;
      };
    };
  };
in
{
  imports = [ treefmt ];
  flake.flakeModules.treefmt = treefmt;
}
