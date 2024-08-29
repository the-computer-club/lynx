{
  networking.firewall.allowedTCPPorts = [8443];
  services.step-ca = {
    enable = true;
    address = "[::]";
    port = 8443;
    # openFirewall = true;
    settings = {
      dnsNames = [ "acme" "acme.vpn" ];
      db = {
        type = "badger";
        dataSource = "/var/lib/step-ca/db";
      };
      authority = {
        provisioners = [
          {
            type = "ACME";
            name = "acme";
          }
        ];
      };
    };
  };
}
