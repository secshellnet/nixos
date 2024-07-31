{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  netbox,
}:
buildPythonPackage rec {
  pname = "netbox-topology-views";
  #version = "3.9.0";
  version = "3.8.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    #hash = "sha256-qjYWmXjwPsxlehYD5JUE2ddPaqDQja7EgGBKVTOWWIs";
    hash = "sha256-9Lfi/ca50Ig0IQHP7YTmbtBeMXfXX2Vx9hsmBtVkGds";
  };

  nativeBuildInputs = [ setuptools ];

  checkInputs = [ netbox ];

  preFixup = ''
    export PYTHONPATH=${netbox}/opt/netbox/netbox:$PYTHONPATH
  '';

  meta = {
    description = "Create topology views/maps from your devices in NetBox";
    homepage = "https://github.com/netbox-community/netbox-topology-views";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
