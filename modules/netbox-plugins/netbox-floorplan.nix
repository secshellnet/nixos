{
  lib,
  callPackage,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  netbox,
}:
buildPythonPackage rec {
  pname = "netbox-floorplan-plugin";
  version = "0.3.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-3/ReEM6ZG5+B4HQmK/cfxUry9kyR4HuyPVvYEcFz14M=";
  };

  nativeBuildInputs = [ setuptools ];

  checkInputs = [ netbox ];

  preFixup = ''
    export PYTHONPATH=${netbox}/opt/netbox/netbox:$PYTHONPATH
  '';

  meta = {
    description = "Netbox plugin providing floorplan mapping capability for locations and sites.";
    homepage = "https://github.com/DanSheps/netbox-floorplan-plugin";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
