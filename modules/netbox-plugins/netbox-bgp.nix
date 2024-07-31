{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  netbox,
}:
buildPythonPackage rec {
  pname = "netbox-bgp";
  version = "0.12.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "netbox-community";
    repo = "netbox-bgp";
    rev = "v${version}";
    hash = "sha256-T/+/JxY9Oyf7e70yK8X/ZaENYbV0f0YmGYtaEmnvhgI=";
  };

  nativeBuildInputs = [ setuptools ];

  checkInputs = [ netbox ];

  preFixup = ''
    export PYTHONPATH=${netbox}/opt/netbox/netbox:$PYTHONPATH
  '';

  meta = {
    description = "Netbox plugin for BGP related objects documentation.";
    homepage = "https://github.com/netbox-community/netbox-bgp";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
