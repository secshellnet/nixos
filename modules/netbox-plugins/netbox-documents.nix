{ lib
, callPackage
, buildPythonPackage
, fetchPypi
, setuptools
, netbox
}: let
  drf-extra-fields = callPackage ./drf-extra-fields.nix {};
in buildPythonPackage rec {
  pname = "netbox-documents";
  version = "0.6.3";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-NSqyXq6ud20MUuOMl1Z8ChdtaTM16kYyzaML7HBG6cw=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    drf-extra-fields
  ];

  checkInputs = [
    netbox
  ];

  preFixup = ''
    export PYTHONPATH=${netbox}/opt/netbox/netbox:$PYTHONPATH
  '';

  meta = {
    description = "Plugin designed to faciliate the storage of site, circuit, device type and device specific documents within NetBox.";
    homepage = "https://github.com/jasonyates/netbox-documents";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
