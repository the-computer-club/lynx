_: { self, inputs, config, lib, pkgs, ... }:
with lib;
let
  cfg = config.deploy;

  generic-settings.options =
  {
    sshOpts = mkOption {
      type = types.listOf types.string;
      default = [];
    };

    sshUser = mkOption {
      type = types.string;
      default = "root";
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

  profile.options = generic-settings.options // {
    path = mkOption {
      default = {};
    };
  };

  nodes.options = generic-settings.options //
  {
    hostname = mkOption {
      type = types.string;
    };

    system = mkOption {
      type = types.string;
      example = "aarch64-linux";
      default = "x86_64-linux";
    };

    profileOrder = mkOption {
      type = types.listOf types.string;
      default = [];
    };

    profiles = mkOption {
      type = types.attrsOf (types.submodule profile);
      default = {};
    };
  };
in
{
  options = {
    deploy = {
      nodes = mkOption {
        type = types.attrsOf (types.submodule nodes);
        default = {};
      };
    } // generic-settings.options;
  };

  config = {
    flake.deploy = cfg;
  };
}
