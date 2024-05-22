{ lib
, callPackage
, buildPythonPackage
, fetchFromGitHub
, setuptools
, netbox
}: let
  drf-extra-fields = callPackage ./drf-extra-fields.nix {};
in buildPythonPackage rec {
  pname = "netbox-documents";
  version = "0.6.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "jasonyates";
    repo = "netbox-documents";
    rev = "v${version}";
    hash = "sha256-BQ33eJAp0Hnc77Mvaq9xAcDqz15fkdCwQ7Q46eOOmaI";
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
