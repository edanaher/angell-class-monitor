{ pkgs ? import <nixpkgs> {}, config, options, lib, modulesPath }:

let angell-packages = import ./default.nix { inherit pkgs angell-password; };
    angell-password = "secure-angell";
    angell-class-monitor = angell-packages.angell-class-monitor;
    pgmoon = angell-packages.pgmoon;
    web-path = "/var/run/angell-classes";
    angell-wrapper = pkgs.writeScriptBin "angell-class-wrapper" ''
      #!/bin/sh
      mkdir -p ${web-path}/raw

      #      now=`date -Iseconds`
      #      cd ${angell-class-monitor}/bin
      #      ./generate.py -o ${web-path}/new-$now.html -r ${web-path}/raw/$now
      #      ln -sf ${web-path}/new-$now.html ${web-path}/index.html
      '';
    pgmoon = pkgs.luaPackages.buildLuaPackage rec {
      _name  = "pgmoon";
      version = "1.8.0";
      name = "${_name}-${version}";
      src = pkgs.fetchFromGitHub {
        owner = "leafo";
        repo = _name;
        rev = "v${version}";
        sha256 = "1ghhqdgm6i5vnr2bw18a19i77j9xbwbb6wn0k81ffpdqrhm0xish";
      };
    };
in
{
  environment.systemPackages = [ angell-class-monitor pkgs.postgresql ];

  systemd.services.update-angell = {
    #enable = false;
    description = "update-angell script";
    after = [ "network.target" "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = { TZ = "America/Los_Angeles"; };
    serviceConfig =  {
      ExecStart = "${angell-wrapper}/bin/angell-class-wrapper";
      Restart = "on-failure";
      RestartSec = "4h";
      StartLimitInterval = "1min";
      PermissionsStartOnly = "true"; # Run postgres setup as root
      User = "angell";
    };

    preStart = ''
      ${angell-class-monitor}/bin/setup.sh ${web-path}
    '';
  };

  services.postgresql.enable = true;
  services.postgresql.authentication = ''
    local angell angell md5
    local all all peer
  '';

  users.users.angell = {
    description = "User to run the angell-class-monitor script";
  };

  networking.firewall.enable = false;
  services.nginx.enable = true;
  services.nginx.package = (pkgs.nginx.overrideAttrs (oldAttrs: { configureFlags = oldAttrs.configureFlags ++ [/*"--with-ld-opt=${pgmoon}/doesnotexit"*/]; } )).override { modules = with pkgs.nginxModules; [ lua ]; };
  services.nginx.appendHttpConfig = ''
    lua_package_path ";;${pgmoon}/lib/?.lua;${pgmoon}/lib/?/init.lua";
  '';
  services.nginx.virtualHosts = {
    "localhost" = {
      locations."/".root = web-path;
      locations."/api" = {
        extraConfig = ''
          default_type text/plain;
          content_by_lua_file ${angell-class-monitor}/lib/handler.lua;
          set $angell_password ${angell-password};
        '';
      };
    };
  };
}
