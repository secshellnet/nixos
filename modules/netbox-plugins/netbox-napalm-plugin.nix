{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  netbox,
  pythonAtLeast,
  napalm,
}:
buildPythonPackage rec {
  pname = "netbox-napalm-plugin";
  version = "0.3.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "netbox-community";
    repo = "netbox-napalm-plugin";
    rev = "v${version}";
    hash = "sha256-nog6DymnnD0ABzG21jy00yNWhSTHfd7vJ4vo1DjsfKs=";
  };

  disabled = pythonAtLeast "3.13";

  build-system = [ setuptools ];

  dependencies = [
    napalm
  ];

  nativeCheckInputs = [ netbox ];

  postPatch = ''
    sed -i 's/napalm<5.0/napalm/' pyproject.toml
  '';

  preFixup = ''
    export PYTHONPATH=${netbox}/opt/netbox/netbox:$PYTHONPATH
  '';

  pythonImportsCheck = [ "netbox_napalm_plugin" ];

  meta = {
    description = "Netbox plugin for Napalm integration";
    homepage = "https://github.com/netbox-community/netbox-napalm-plugin";
    changelog = "https://github.com/netbox-community/netbox-napalm-plugin/releases/tag/${src.rev}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ felbinger ];
  };
}
