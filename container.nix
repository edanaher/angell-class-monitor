{ pkgs ? import <nixpkgs> {}, config, options, lib, modulesPath }:

let angell-packages = import ./default.nix { inherit pkgs angell-password; template-path = "${web-path}/templates"; };
    angell-password = "secure-angell";
    angell-class-monitor = angell-packages.angell-class-monitor;
    mail-host = "10.233.1.1";
    web-path = "/var/run/angell-classes";
    template-path = "${web-path}/templates";
    angell-wrapper = pkgs.writeScriptBin "angell-class-wrapper" ''
      #!/bin/sh
      mkdir -p ${web-path}/raw
      mkdir -p ${web-path}/templates

      #now=`date -Iseconds`
      now=2018-01-12T18:53:43-08:00
      cd ${angell-class-monitor}/bin
      #./generate.py -o ${web-path}/new-$now.html -t ${template-path}/new-$now.html -r ${web-path}/raw/$now
      ./generate.py -o ${web-path}/new-$now.html -t ${template-path}/new-$now.html -r ${web-path}/raw/$now -d
      ln -sf ${web-path}/new-$now.html ${web-path}/index.html
      ln -sf ${template-path}/new-$now.html ${template-path}/index.html
      '';
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
    lua_package_path ";;${angell-packages.lua-path};";
  '';
  services.nginx.virtualHosts = {
    "localhost" = {
      locations."/_static".alias = web-path;
      locations."/" = {
        extraConfig = ''
          default_type text/plain;
          content_by_lua_file ${angell-class-monitor}/lib/handler.lua;
          set $angell_password ${angell-password};
          set $template_root ${template-path};
          set $mail_host ${mail-host};
        '';
      };
    };
  };
}
