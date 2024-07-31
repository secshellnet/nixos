{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  qrcode,
  pillow,
  netbox,
}:
buildPythonPackage rec {
  pname = "netbox-qrcode";
  version = "0.0.11";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-tLr4OOfUF91vuAJvV58evt6+VRQ5SFpxY2qV8Yqm7lc=";
  };

  nativeBuildInputs = [ setuptools ];

  propagatedBuildInputs = [
    qrcode
    pillow
  ];

  checkInputs = [ netbox ];

  preFixup = ''
    export PYTHONPATH=${netbox}/opt/netbox/netbox:$PYTHONPATH
  '';

  meta = {
    description = "Netbox plugin for generate QR codes for objects: Rack, Device, Cable.";
    homepage = "https://github.com/netbox-community/netbox-qrcode";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
