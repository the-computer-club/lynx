{ config, lib, ... }:
let
  inherit (lib)
    optionals
    mkOption
    mkMerge
    types
    ;

  cfg = config.lynx.docgen;
in
{
  options.lynx.docgen = {
    flakeModules = mkOption {
      type = types.nullOr (types.listOf types.anything);
      default = null;
    };

    nixosModules = mkOption {
      type = types.nullOr (types.listOf types.anything);
      default = null;
    };

    repository = {
      baseUri = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  config.perSystem = args@{ config, inputs', pkgs, lib, system, ... }:
    let
      cleanDocs = pkgs.callPackage ({
        stdenv
        , name
        , src
        , uri ? null
        , htmlSafe ? false
        , runCommand
        , gnused
        , coreutils
      }: runCommand name { buildInputs = [ gnused coreutils ]; }
      ''
        cat ${src.out} \
          ${if htmlSafe then
            ''| sed -e "s|\\\<|\&lt\;|g"'' else "" } \
          ${if uri != null then
            ''| sed -e "s|file:///nix/store/.*-source/|${uri}|g"''
            else ""} \
        > $out
      '');

      generate = pkgs.callPackage ({
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
            inherit modules;
            check = false; # ignore warnings
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
        uri = cfg.repository.baseUri;
        modules =
          cfg.flakeModules
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
        uri = cfg.repository.baseUri;
        modules = cfg.nixosModules;
      };

      packages.generateDocsHTML = pkgs.callPackage ({
        lib
        , stdenv
        , python3
        , mkdocsYaml
        , mdDocs ? []
        , ...
      }:
        stdenv.mkDerivation {
          name = "docs";
          phases = "installPhase";

          nativeBuildInputs =
            [
              (python3.withPackages(ps: [
                # mkdocs doesn't like
                # overriding mkdocs-materials
                ps.mkdocs
                ps.mkdocs-material
              ]))
            ];

          installPhase =
              ''
              mkdir -p $out/docs docs
              ${builtins.concatStringsSep "\n" (map (s: "ln -s ${s} docs/${s.name}") mdDocs) }
              python -m mkdocs build -f ${mkdocsYaml}
              mv site docs $out
              ''
            ;
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

          mdDocs =
            map (md: cleanDocs { src = md; htmlSafe = true; uri=cfg.repository.baseUri; name=md.name; })
              (
                (optionals (cfg.nixosModules != null) [ config.packages.nixosDocsMD ])
                ++
                (optionals (cfg.flakeModules != null) [ config.packages.flakeDocsMD ])
              );
        };
    };
}
