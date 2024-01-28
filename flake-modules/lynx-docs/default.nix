_: { self, inputs, config, lib, pkgs, ... }:
{
  config.perSystem = args@{ config, self', inputs', pkgs, lib, system, ... }:
    let generate = pkgs.callPackage ({
        lib
        , name
        , runCommand
        , nixosOptionsDoc
        , gnused
        , coreutils
        , modules ? []
        , htmlSafe ? false
        , uri ? null
        , ...
      }:
        let
          eval = lib.evalModules {
            modules = map (x: x // { config._module.check = false; }) modules;
          };

          docs = nixosOptionsDoc {
            inherit (eval) options;
            warningsAreErrors = false;
          };
        in
          runCommand name {
            buildInputs = [ gnused coreutils ];
          }
          ''
            cat ${docs.optionsCommonMark} \
              ${if htmlSafe then
                ''| sed -e "s|\\\<|\&lt\;|g"'' else "" } \
              ${if uri != null then
                ''| sed -e "s|file:///nix/store/.*-source/|${uri}|g"''
                else ""} \
              > $out
          ''
      );
    in
    {
      packages.flakeDocsMD = generate {
        name = "flake-options.md";
        htmlSafe = true;
        uri = self.repository.uri;

        modules =
          (builtins.attrValues self.flakeModules)
          ++
          # Needed for flake parts.
          [{ options.flake = lib.mkOption {
               type = lib.types.attrsOf lib.types.anything;
               default = {};
               description = "Flake Toplevel options";
             };
          }];
      };

      packages.nixosDocsMD = generate {
        name = "nixos-options.md";
        htmlSafe = true;
        uri = self.repository.uri;
        modules = builtins.attrValues self.nixosModules;
      };

      packages.generateDocsHTML = pkgs.callPackage ({
        lib
        , stdenv
        , python3
        , mkdocsYaml
        , mdDocs ? []
        , ...
      }:
        pkgs.stdenv.mkDerivation {
          name = "docs";
          phases = "installPhase";

          nativeBuildInputs = [
            (python3.withPackages( ps: [
              # mkdocs doesn't like
              # overriding mkdocs-materials
              ps.mkdocs
              ps.mkdocs-material
            ]))
          ];

          installPhase = builtins.concatStringsSep "\n" (
            [
            ''
            mkdir -p $out/docs docs
            ''
            ]
            ++
            ((map (p: "ln -s ${p} docs/${p.name}") mdDocs))
            ++
            [''
            python -m mkdocs build -f ${mkdocsYaml}
            mv site docs $out
            '']
          );
        })
        {
          mkdocsYaml = pkgs.writeText "mkdocs.yml" ''
            site_name: Lynx options
            site_url: https://unallocatedspace.dev/docs/
            repo_url: https://github.com/the-computer-club/lynx/
            docs_dir: /build/docs
            site_dir: /build/site
            nav_style: dark
            theme:
              name: material
              palette:
                scheme: slate
          '';

          mdDocs = [
            config.packages.nixosDocsMD
            config.packages.flakeDocsMD
          ];
        };
    };
}
