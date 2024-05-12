{ lib
, buildPythonPackage
, fetchPypi
, setuptools
}: buildPythonPackage rec {
  pname = "netbox-floorplan-plugin";
  version = "0.3.4";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-3/ReEM6ZG5+B4HQmK/cfxUry9kyR4HuyPVvYEcFz14M=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  meta = with lib; {
    description = "A netbox plugin providing floorplan mapping capability for locations and sites.";
    homepage = "https://github.com/DanSheps/netbox-floorplan-plugin";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
