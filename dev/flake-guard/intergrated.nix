{ config, lib, pkgs, ... }:
let cfg = config.wireguard.networks.testnet.self;
in {

  wireguard.networks.self.autoConfig.enableACME = lib.mkForce false;

  security.acme = {
    acceptTerms = true;
    defaults.email = "integrated@example.org";
  };

  services.nginx = {
    enable = true;
    virtualHosts.${cfg.fqdn} = {
      forceSSL = true;
      enableACME = true;
    };
  };
}
