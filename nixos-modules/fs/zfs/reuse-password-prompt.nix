# ZFS Ephemeral encrypted
# based on pass phrase passing
# ###
# todo: fuck around and find out
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.boot.zfs;
  mkPasswordPromptStr = mkOrder 1502;
in
{
  options.lynx.boot.zfs.passwordUnlocks = mkOption {
      type = types.listOf types.nonEmptyStr;
      default = [];
  };

  config.boot = mkIf (cfg.passwordUnlocks != []) {
    # Use our own requests
    zfs.requestEncryptionCredentials = lib.mkDefault false;

    initrd.postDeviceCommands = mkPasswordPromptStr
      (builtins.concatStringsSep "\n"
      [
        ''
        TRYPASS=""
        ''
        (
          builtins.concatStringsSep "\n" (map (ds:
            ''
            tries=3
            success=false
            while [[ $success != true ]] && [[ $tries -gt 0 ]]; do
                if [[ -z "$TRYPASS" ]]; then
                    read -sp "Enter key for ${ds}:" TRYPASS
                fi
                echo "$TRYPASS" | zfs load-key "${ds}" && success=true
                if [[ $success != true ]]; then
                    echo "Wrong key, try again"
                    TRYPASS=""
                    tries=$((tries-1))
                fi
            done
            [[ $success = true ]]
            ''
            ) cfg.passwordUnlocks
          )
        )

        ''
        unset -v TRYPASS tries success
        ''
      ]);
  };
}
