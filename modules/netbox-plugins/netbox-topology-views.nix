{ lib
, buildPythonPackage
, fetchPypi
, setuptools
}: buildPythonPackage rec {
  pname = "netbox-topology-views";
  #version = "3.9.0";
  version = "3.8.1";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    #hash = "sha256-qjYWmXjwPsxlehYD5JUE2ddPaqDQja7EgGBKVTOWWIs";
    hash = "sha256-9Lfi/ca50Ig0IQHP7YTmbtBeMXfXX2Vx9hsmBtVkGds";
  };

  nativeBuildInputs = [
    setuptools
  ];

  meta = with lib; {
    description = "Create topology views/maps from your devices in NetBox";
    homepage = "https://github.com/netbox-community/netbox-topology-views";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
