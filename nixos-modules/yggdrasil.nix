{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkOptionDefault mkIf;
  cfg = config.lynx.networking.yggdrasil;
in {
  options.lynx.networking.yggdrasil = {
    enable = mkEnableOption "enables yggdrasil a sdwan solution";
  };
  config = mkIf cfg.enable {
    services.yggdrasil =  {
      enable = mkOptionDefault true;
      openMulticastPort = mkOptionDefault true;
      persistentKeys = mkOptionDefault true;
      settings = {
        Peers = mkOptionDefault ["tls://ygg.yt:443"];
        MulticastInterfaces = mkOptionDefault [
          {
            Regex = "w.*";
            Beacon = true;
            Listen = true;
            Port = 9001;
            Priority = 0;
          }
        ];
        AllowedPublicKeys = mkOptionDefault [];
        IfName = mkOptionDefault "auto";
        IfMTU = mkOptionDefault 65535;
        NodeInfoPrivacy = mkOptionDefault false;
        NodeInfo = mkOptionDefault null;
      };
    };
  };
}
