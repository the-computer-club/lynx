_: { self, inputs, config, lib, pkgs, ... }:
with lib;
let
  cfg = config.deploy;

  generic-settings.options =
  {
    sshOpts = mkOption {
      type = types.listOf types.string;
      default = [];
      description = '' This is an optional list of arguments that will be passed to SSH. '';
    };

    sshUser = mkOption {
      type = types.string;
      default = "root";
      description = ''
        This is the user that the profile will be deployed to (will use sudo if not the same as above).
        If `sshUser` is specified, this will be the default (though it will _not_ default to your own username)
        '';
    };

    user = mkOption {
      type = types.string;
      default = "root";
      description = ''
        This is the user that deploy-rs will use when connecting.
        This will default to your own username if not specified anywhere
        '';
    };

    sudo = mkOption {
      type = types.string;
      default = "sudo -u";
      description = ''
        Which sudo command to use. Must accept at least two arguments:
        the user name to execute commands as and the rest is the command to execute
        This will default to "sudo -u" if not specified anywhere.
        '';
    };

    magicRollback = mkOption {
      type = types.bool;
      default = true;
      description = ''
        There is a built-in feature to prevent you making changes that might render your machine unconnectable or unusuable,
        which works by connecting to the machine after profile activation to confirm the machine is still available,
        and instructing the target node to automatically roll back if it is not confirmed.
        If you do not disable magicRollback in your configuration (see later sections) or with the CLI flag,
        you will be unable to make changes to the system which will affect you connecting to it
        (changing SSH port, changing your IP, etc).
        '';
    };

    autoRollback = mkOption {
      type = types.bool;
      default = true;
      description = ''
        If the previous profile should be re-activated if activation fails.
        This defaults to `true`
        '';
    };

    fastConnection = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Fast connection to the node.
        If this is true, copy the whole closure instead of letting the node substitute.
        This defaults to `false`
        '';
    };

    tempPath = mkOption {
      type = types.path;
      default = "/tmp";
      description = ''
        The path which deploy-rs will use for temporary files, this is currently only used by `magicRollback` to create an inotify watcher in for confirmations
        If not specified, this will default to `/tmp`
        (if `magicRollback` is in use, this _must_ be writable by `user`)
        '';
    };

    remoteBuild = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Build the derivation on the target system.
        Will also fetch all external dependencies from the target system's substituters.
        This default to `false`
        '';
    };

    activationTimeout = mkOption {
      type = types.int;
      default = 240;
      description = ''
        Timeout for profile activation.
        This defaults to 240 seconds.
        '';
    };

    confirmTimeout = mkOption {
      type = types.int;
      default = 30;
      description = ''
        Timeout for confirmation.
        This defaults to 30 seconds.
        '';
    };
  };

  profile.options = generic-settings.options // {
    path = mkOption {
      default = {};
      description = ''
      A derivation containing your required software, and a script to activate it in `''${path}/deploy-rs-activate`
      For ease of use, `deploy-rs` provides a function to easily add the required activation script to any derivation
      Both the working directory and `$PROFILE` will point to `profilePath`
      '';
    };

    profilePath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
      An optional path to where your profile should be installed to, this is useful if you want to use a common profile name across multiple users, but would have conflicts in your node's profile list.
      This will default to `"/nix/var/nix/profiles/system` if `user` is `root` and profile name is `system`,
      `/nix/var/nix/profiles/per-user/root/$PROFILE_NAME` if profile name is different.
      For non-root profiles will default to /nix/var/nix/profiles/per-user/$USER/$PROFILE_NAME if `/nix/var/nix/profiles/per-user/$USER` already exists,
      and `''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/$PROFILE_NAME` otherwise.
      '';
    };
  };

  nodes.options = generic-settings.options //
  {
    hostname = mkOption {
      type = types.str;
       description = "The hostname of your server. Can be overridden at invocation time with a flag.";
    };

    profileOrder = mkOption {
      type = types.listOf types.string;
      default = [];
      description = ''
        An optional list containing the order you want profiles to be deployed.
        This will take effect whenever you run `deploy` without specifying a profile, causing it to deploy every profile automatically.
        Any profiles not in this list will still be deployed (in an arbitrary order) after those which are listed
        '';
    };

    profiles = mkOption {
      type = types.attrsOf (types.submodule profile);
      default = {};
      description = ''
       allows for lesser-privileged deployments,
       and the ability to update different things independently of each other.
       You can deploy any type of profile to any user, not just a NixOS profile to root.
       '';
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
