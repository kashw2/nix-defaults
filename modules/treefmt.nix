{ inputs, ... }:
let
  treefmt = {
    imports = [
      inputs.treefmt-nix.flakeModule
    ];

    perSystem = { config, ... }: {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.deadnix.enable = true;
        programs.statix.enable = true;
        programs.actionlint.enable = true;
        programs.dockerfmt.enable = true;
        programs.gofmt.enable = true;
        programs.mdformat.enable = true;
        programs.shfmt.enable = true;
        programs.jsonfmt.enable = true;
        programs.terraform.enable = true;
        programs.d2.enable = true;
        # Defer to the specialized formatter when it owns the file type
        programs.prettier.excludes =
          (if config.treefmt.programs.mdformat.enable then [ "*.md" ] else [ ])
          ++ (if config.treefmt.programs.jsonfmt.enable then [ "*.json" ] else [ ]);
      };
    };
  };
in
{
  imports = [ treefmt ];
  flake.flakeModules.treefmt = treefmt;
}
