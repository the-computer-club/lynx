{self, inputs, ...}: {

  imports = [
    inputs.profile-parts.flakeModules.home-manager
  ];

  profile-parts.default.home-manager = {
    inherit (inputs) home-manager nixpkgs;
    enable = true;
    system = "x86_64-linux";
    exposePackages = true;
    username = "lunarix";
  };

  profile-parts.global.home-manager = {
    modules = [];
    # alternative:
    # { name, profile }: [];

    specialArgs = { inherit self inputs; };
  };


  profile-parts.home-manager = {
    lunarix = {
      home-manager = inputs.home-manager;
      nixpkgs = inputs.nixpkgs;

      username = "lunarix";
      directory = "/home/lunarix";

      modules = [
        {
          home.stateVersion = "23.05";
        }
      ];

      specialArgs = {inherit inputs;};
    };
  };
}
