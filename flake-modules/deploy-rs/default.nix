_: { self, inputs, config, lib, pkgs, ... }:
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

  profile.options =
  {
    path = mkOption {
      default = null;
    };

    sshOpts = mkOption {
      type = types.listOf types.string;
      default = config.deploy.defaultSshOpts;
    };

    sshUser = mkOption {
      type = types.string;
      default = config.deploy.defaultSshUser;
    };

    user = mkOption {
      type = types.string;
      default = "root";
    };

    sudo = mkOption {
      type = types.string;
      default = "sudo -u";
    };

    magicRollback = mkOption {
      type = types.bool;
      default = true;
    };

    autoRollback = mkOption {
      type = types.bool;
      default = true;
    };

    fastConnection = mkOption {
      type = types.bool;
      default = false;
    };

    tempPath = mkOption {
      type = types.path;
      default = "/tmp";
    };

    remoteBuild = mkOption {
      type = types.bool;
      default = false;
    };

    activationTimeout = mkOption {
      type = types.int;
      default = 240;
    };

    confirmTimeout = mkOption {
      type = types.int;
      default = 30;
    };
  };

  nodes.options = {
    hostname = mkOption {
      type = types.string;
    };

    system = mkOption {
      type = types.string;
      example = "aarch64-linux";
    };

    profileOrder = mkOption {
      type = types.listOf types.string;
      default = [];
    };

    profiles = mkOption {
      type = types.attrsOf (types.submodule profile);
      default = {
        system.path = null;
      };
    };
  };

in
# flake.deploy.defaultSshUser = "storm";
# flake.deploy.nodes.host.user = "lunarix";

{
  options.deploy = {
    input = mkOption {
      type = types.lazyAttrsOf types.attrs;
    };

    defaultSystem = mkOption {
      type = types.string;
      default = "x86_64-linux";
    };

    defaultSshOpts = mkOption {
      type = types.listOf types.string;
      default = [];
    };

    defaultSshUser = mkOption {
      type = types.string;
      default = "root";
    };

    defaultUser = mkOption {
      type = types.string;
      default = "root";
    };

    nodes = mkOption {
      type = types.attrsOf (types.submodule nodes);
      default = {};
    };
  };

  config = mkIf cfg.enable
  {
    flake.deploy = cfg // {
      nodes = (builtins.mapAttrs (k: v:
        v // {
          path =
            if v.profiles.system.path != null then
              v.profiles.system.path
            else
              config.deploy.input.lib.${config.deploy.nodes.${k}.system}.activate.nixos
                self.nixosConfigurations.${k};
        }
      ) cfg.nodes);
    };
  };
}
