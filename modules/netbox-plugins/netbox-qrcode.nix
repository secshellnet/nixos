{ lib
, buildPythonPackage
, fetchPypi
, setuptools
, qrcode
, pillow
}: buildPythonPackage rec {
  pname = "netbox-qrcode";
  version = "0.0.11";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-tLr4OOfUF91vuAJvV58evt6+VRQ5SFpxY2qV8Yqm7lc=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    qrcode
    pillow
  ];

  meta = with lib; {
    description = "Netbox plugin for generate QR codes for objects: Rack, Device, Cable.";
    homepage = "https://github.com/netbox-community/netbox-qrcode";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
