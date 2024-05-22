{ lib
, buildPythonPackage
, fetchPypi
, setuptools
, django
, djangorestframework
, filetype
}: buildPythonPackage rec {
  pname = "drf-extra-fields";
  version = "3.7.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-1+WLj2BDIjMyi4pkgx5Q6l0Fky08tjrej+ZsDT0hrFs=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    filetype
  ];

  checkInputs = [
    django
    djangorestframework
  ];

  meta = {
    description = "Extra Fields for Django Rest Framework";
    homepage = "https://github.com/Hipo/drf-extra-fields";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
