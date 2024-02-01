{ config, self, inputs, ... }:
{
  imports = [
    inputs.lynx.flakeModules.deploy-rs
  ];

  deploy = {
    sshUser = "lunarix";
    user = "root";

    magicRollback = false;
    nodes = {
      cypress = {
        hostname = "10.0.0.5";
        profiles.system = {
          path = inputs.deploy.lib."x86_64-linux".activate.nixos
            self.nixosConfigurations.default;
        };
      };
    };
  };
}
