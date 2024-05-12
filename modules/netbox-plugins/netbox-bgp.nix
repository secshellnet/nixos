{ lib
, buildPythonPackage
, fetchPypi
, setuptools
}: buildPythonPackage rec {
  pname = "netbox-bgp";
  version = "0.12.1";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-U79NJQlSI4I3t100a2lHgCLYmUplIaGrh1uljlYnYIs=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  meta = with lib; {
    description = "Netbox plugin for BGP related objects documentation.";
    homepage = "https://github.com/netbox-community/netbox-bgp";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
