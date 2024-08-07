{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  numpy,
  poetry-core,
  invoke,
  requests,
  pynetbox,
  paramiko,
  fastapi,
  starlette,
  uvicorn,
  websockets,
  jinja2,
  ujson,
  orjson,
  httpcore,
  netbox,
  proxmoxer,
  packaging
}:
# TODO
# ERROR Missing dependencies:
#   pynetbox, packaging<24.0
buildPythonPackage rec {
  pname = "netbox-proxbox";
  version = "0.0.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "netdevopsbr";
    repo = "netbox-proxbox";
    rev = "v${version}";
    hash = "sha256-DusIDNGvkzCO0a7QlTGQfZ2jjYN+yT0qp3WwB/eb1rY=";
  };

  build-system = [ setuptools ];

  dependencies = [
    numpy
    poetry-core
    invoke
    requests
    pynetbox
    paramiko
    fastapi
    starlette
    uvicorn
    websockets
    jinja2
    ujson
    orjson
    httpcore
    proxmoxer
    packaging
  ];

  checkInputs = [ netbox ];

  meta = {
    description = "Netbox Plugin for integration between Proxmox and Netbox.";
    homepage = "https://github.com/netdevopsbr/netbox-proxbox";
    changelog = "https://github.com/netdevopsbr/netbox-proxbox/releases/tag/${src.rev}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
