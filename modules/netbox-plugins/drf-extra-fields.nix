{ lib
, buildPythonPackage
, fetchPypi
, setuptools
}: buildPythonPackage rec {
  pname = "drf-extra-fields";
  version = "3.7.0";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-1+WLj2BDIjMyi4pkgx5Q6l0Fky08tjrej+ZsDT0hrFs=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  meta = with lib; {
    description = "Extra Fields for Django Rest Framework";
    homepage = "https://github.com/Hipo/drf-extra-fields";
    license = licenses.asl20;
    platforms = platforms.linux;
  };
}
