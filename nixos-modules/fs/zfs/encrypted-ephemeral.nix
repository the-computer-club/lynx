# ZFS Ephemeral encrypted
# based on pass phrase passing
# ###
# todo: fuck around and find out
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.lynx.boot.zfs.ephemeral;
  mkEZfs = mkOrder 1501;
in
{
  options.lynx.boot.zfs.ephemeral = {
    datasets = mkOption {
      default = [];
      type = types.listOf types.nonEmptyStr;
    };
  };

  config = mkIf (cfg.datasets != []) {
    boot.initrd.postDeviceCommands = mkEZfs (builtins.concatStringsSep "\n"
    [
      (
        # echo "${cfg.destroy}" | sed s/%ds/${ds}/g | exec
        builtins.concatStringsSep "\n" (map (ds:
        ''
        echo [ . ] destroying ${ds}
        zfs destroy ${ds}
        echo [ + ] destroyed ${ds}
        ''
        ) cfg.datasets
      ))

      (
        builtins.concatStringsSep "\n" (map (ds:
        ''
        echo [ . ] creating ${ds}

        dd if=/dev/urandom bs=512 count=1 2>/dev/null \
          | sed -e 's/[[:space:]]*//' \
          | zfs create \
              -o mountpoint=legacy \
              -o encryption=aes-256-gcm \
              -o keylocation=prompt \
              -o keyformat=passphrase \
        ${ds}

        echo [ + ] created ${ds}
        ''
        ) cfg.datasets
      ))
    ]);
  };
}
