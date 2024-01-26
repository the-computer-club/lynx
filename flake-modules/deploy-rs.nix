{ self, config, lib, pkgs, inputs, ... }:
####
# Flake module for deploy-rs
### Example:
# flake-parts.mkFlake {
#   deploy.input = inputs.deploy-rs;
#   deploy.defaultSshUser = "lunarix";
#   deploy.nodes.vps-host.hostname = "1.1.1.1";
#   nixosConfiguration.vps-host = nixpkgs.lib.nixosSystem { ... };
# }
### deploy
# nix shell nixpkgs#deploy-rs \
#  -c "LOCAL_KEY=/var/store/key deploy /etc/nixos#vps-host --impure"
#
with lib;
let
  cfg = config.deploy;

  nodeSettings = settings:
    { options = builtins.removeAttrs ["system"] settings.options; };

  clusterSettings =
    { options = builtins.removeAttrs ["path"] settings.options; };

  deployCluster =
    {deploy-rs, writeShellScript, signingKey, nodes, uri}:
      writeShellScript {
        text = builtins.concatStringSep "\n" (map (node: ''
          URI=\''${1:-${URI}}
          LOCAL_KEY=${signingKey} ${deploy-rs}/bin/deploy ${uri}#${node}
        '') nodes) ;
      };

  deployWrapper =
    {deploy-rs, writeShellScript, signingKey}:
      config.deploy.packages."${config.host.system}".default.overrideAttrs (old: {
        nativeBuildInputs = [ pkgs.mkWrapper ];
        installPhase = old.installPhase ++ ''
          wrapProgram $out/bin/deploy \
            --set LOCAL_KEY ${config.deploy.settings.signingKey}
        '';
      });


  clusterModule = backref:
  {
    options = {
      _cluster = mkOption {
        type = types.string;
        default = builtins.tail backref;
      };

      _backref = mkOption {
        type = types.listOf types.string;
        default = backref;
      };

      nodes = mkOption {
        type = types.attrsOf (types.submodule nodes);
        default = {};
      };

      settings = mkOption {
        type = types.attrsOf (types.submodule settingsModule backref );
        default = config.deploy.settings;
      };
    };
  };


  nodesModule = backref:
    let
      lookup = backref ++ ["settings"];
      cfg = getAttrFromPath lookup config;
    in
    {
      options = {
        system = mkOption {
          type = types.string;
          default = cfg.system;
        };

        hostname = mkOption {
          type = types.string;
        };

        profileOrder = mkOption {
          type = types.listOf types.string;
          default = cfg.profileOrder;
        };

        # profiles/settings
        profiles = mkOption {
          type = types.attrsOf (types.submodule (
            settingsModule backref config
          ));

          default = {
            system.path = null;
          };
        };
      };

    };

  settingsSubModule = backref: # ["config" "deploy" "cluster" "settings"]
    let
      # ["config" "deploy" "cluster" "settings"]
      lookup = backref ++ ["settings"];
      cfg = getAttrFromPath lookup config;
    in
  {
    options =
    {
      signingKey = mkOption {
        type = types.path;
        default = cfg.signingKey;
      };

      package = mkOption {
        type = types.derivation;
        default = pkgs.callPackage deployWrapper {
          signingKey = cfg.signingKey;
        };
      };
      #####
      path = mkOption {
        type = types.any;
        default = null;
      };
      sshOpts = mkOption {
        type = types.listOf types.string;
        default = cfg.sshOpts;
      };
      sshUser = mkOption {
        type = types.string;
        default = cfg.sshUser;
      };
      magicRollback = mkOption {
        type = types.bool;
        default = cfg.magicRollback;
      };
      autoRollback = mkOption {
        type = types.bool;
        default = cfg.autoRollback;
      };
      user = mkOption {
        type = types.string;
        default = cfg.user;
      };
      sudo = mkOption {
        type = types.string;
        default = cfg.sudo;
      };
      fastConnection = mkOption {
        type = types.bool;
        default = cfg.fastConnection;
      };
      tempPath = mkOption {
        type = types.path;
        default = cfg.tempPath;
      };
      remoteBuild = mkOption {
        type = types.bool;
        default = cfg.remoteBuild;
      };
      activationTimeout = mkOption {
        type = types.int;
        default = cfg.activationTimeout;
      };
      confirmTimeout = mkOption {
        type = types.int;
        default = cfg.confirmTimeout;
      };
    };
  };
in
{
  options.deploy = {
    input = mkOption {
      type = types.lazyAttrsOf types.attrs;
    };

    settings = mkOption {
      type = types.attrsOf (types.submodule
        (settingsModule ["config" "deploy"])
      );
      default = {};
    };

    cluster = mkOption {
      type = types.attrsOf (types.submodule
        (clusterModule ["config" "deploy" "cluster"] )
      );
      default = {};
    };

    nodes = mkOption {
      type = types.attrsOf (types.submodule node-options ["config" "deploy" ] );
    };
  };

  config = mkIf cfg.enable
  {
    deploy.settings = {
      system = mkOptionDefault "x86_64-linux";
      signingKey = mkOptionDefault "/run/secrets/store-signing-key";


      sshOpts = mkOptionDefault [];
      user = mkOptionDefault "root";
      sshUser = mkOptionDefault "root";
      magicRollback = mkOptionDefault true;
      automaticRollback = mkOptionDefault true;
      sudo = mkOptionDefault "sudo -u";
      fastConnection = mkOptionDefault false;
      tempPath = mkOptionDefault "/tmp";
      remoteBuild = mkOptionDefault false;
      activationTimeout = mkOptionDefault 240;
      confirmTimeout = mkOptionDefault 30;
    };

    flake.deploy =
      mkMerge [
        cfg

        ({...}:
        {

          flake.deploy.clusters =
            let
              deploy-lib = config.deploy.input.lib.${config.deploy.system};
            in

            builtins.mapAttrs (cluster-name: cluster-set:
              (builtins.removeAttrs [ "package" "signingKey"] cluster-set.settings) //
              {
                nodes = builtins.mapAttrs (node-name: node-set:
                  (builtins.removeAttrs ["system" "package" "signingKey"] node-set.settings) //
                  {
                    path =
                      if v.profiles.system.path != null then
                        v.profiles.system.path
                      else
                        deploy-lib.activate.nixos
                          self.nixosConfigurations.${node-name};

                  }) cluster-set.nodes
              }) cfg.clusters;

          flake.deploy.nodes =
            let
              deploy-lib = config.deploy.input.lib.${config.deploy.nodes.${node-name}.system};
            in
              (builtins.mapAttrs (node-name: node-set:
                (builtins.removeAttrs ["system" "package" "signingKey"] node-set.settings) //
                {
                  path =
                    if v.profiles.system.path != null then
                      v.profiles.system.path
                    else
                      deploy-lib.activate.nixos
                        self.nixosConfigurations.${node-name};

                }) cluster-set.nodes
              ) cfg.clusters


        })
      ];

  };
}
