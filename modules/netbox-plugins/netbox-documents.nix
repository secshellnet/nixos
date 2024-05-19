{ lib
, buildPythonPackage
, fetchPypi
, setuptools
, netbox
}: buildPythonPackage rec {
  pname = "netbox-documents";
  version = "0.6.3";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-NSqyXq6ud20MUuOMl1Z8ChdtaTM16kYyzaML7HBG6cw=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  checkInputs = [
    netbox
  ];

  preFixup = ''
    export PYTHONPATH=${netbox}/opt/netbox/netbox:$PYTHONPATH
  '';

  meta = with lib; {
    description = "A plugin designed to faciliate the storage of site, circuit, device type and device specific documents within NetBox.";
    homepage = "https://github.com/jasonyates/netbox-documents";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
