{ pkgs ? import <nixpkgs> {} }:

pkgs.python3Packages.buildPythonApplication {
  name = "angell-class-monitor";

  src = ./.;

  propagatedBuildInputs = with pkgs.python3Packages; [ docopt psycopg2 ];

  buildPhase = "";

  installPhase = ''
    mkdir -p $out/bin/
    cp generate.py $out/bin
    cp template.html $out/bin

    substitute setup.sh $out/bin/setup.sh --replace @SUDO@ ${pkgs.sudo} --replace @POSTGRESQL ${pkgs.postgresql} --replace @OUT@ $out
    chmod +x $out/bin/setup.sh

    mkdir -p $out/etc
    cp angell.sql $out/etc/
  '';

  doCheck = false;

  meta = {
    homepage = http://github.com/edanaher/angell-class-monitor;
    description = "Service for watching for changes in classes at the MSPCA Angell in Boston";
    license = pkgs.stdenv.lib.licenses.bsd3;
  };
}
