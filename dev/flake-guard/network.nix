{
  wireguard.networks.testnet = {
    listenPort = 51820;
    domainName = "vpn";

    autoConfig = {
      "networking.wireguard" = {
        interface.enable = true;
        peers.mesh.enable = true;
      };

      "networking.hosts".FQDNs.enable = true;
    };

    metadata.acmeServer = "https://acme:8443/acme/testnet/directory";

    peers.by-name = {
      acme = {
        ipv4 = ["172.16.169.1/32"];
        publicKey = "3rVr8zvOVcOxmlA41tpPoYAiZJcFDPX21D7MsVoUqFY=";
        privateKey = "MLYIn9QSMgzgoVAna3pGmy6UajzcrStN2d/546HmgEE=";
        selfEndpoint = "acme:51820";
      };

      client = {
        ipv4 = ["172.16.169.2/32"];
        publicKey = "hvoRk9k84yYcThG2qwilWuBQUJpBrgMs6dMBg7PD2Qc=";
        privateKey = "CHyebeznokFGkyo2WYWZWzdgWTug8wHnZjjsgsxFFlY=";
        selfEndpoint = "client:51820";
      };

      caddy = {
        ipv4 = ["172.16.169.3/32"];
        publicKey = "wR9cRwbvNO8ogCamR5xL2Zjh+LLBtGdjf3rj6uhlml8=";
        privateKey = "8HmxTjhd/fw2Om2EPO7hkJEbSKn4P9mFhA01ddrCj08=";
        selfEndpoint = "caddy:51820";
      };

      tester = {
        ipv4 = ["172.16.169.4/32"];
        publicKey = "4j2NKmVgE/3iCcFbmtq6Pmvz8HDShI+jRlkEdDmKjmk=";
        privateKey = "yCX0xVDvnIhhFuo/xehG16IS1nKaNMT7cI5YIxwMGXs=";
        selfEndpoint = "tester:51820";
      };
    };
  };
}
