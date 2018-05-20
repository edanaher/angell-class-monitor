{ pkgs ? import <nixpkgs> {}, config, options, lib, modulesPath }:

let angell-packages = import ./default.nix { inherit pkgs angell-password web-path template-path; debug-mode = true; };
    angell-password = "secure-angell";
    angell-class-monitor = angell-packages.monitor-script;
    mail-host = "10.233.1.1";
    web-path = "/var/run/angell-classes";
    template-path = "${web-path}/templates";
    angell-wrapper = angell-packages.wrapper;
in
{
  environment.systemPackages = [ angell-class-monitor pkgs.postgresql ];

  systemd.services.update-angell = angell-packages.service;

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
    lua_package_path ";;${angell-packages.lua-path}";
  '';
  services.nginx.virtualHosts = {
    "localhost" = angell-packages.nginx-locations;
  };

  system.nixos.stateVersion = "18.09";
}
