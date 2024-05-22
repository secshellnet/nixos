{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, django
, djangorestframework
, filetype
}: buildPythonPackage rec {
  pname = "drf-extra-fields";
  version = "3.7.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "hipo";
    repo = "drf-extra-fields";
    rev = "v${version}";
    hash = "sha256-Ym4vnZ/t0ZdSxU53BC0ducJl1YiTygRSWql/35PNbOU";
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
