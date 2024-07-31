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
}:
buildPythonPackage rec {
  pname = "netbox-proxbox";
  version = "0.0.5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "netdevopsbr";
    repo = "netbox-proxbox";
    rev = "v${version}";
    hash = "sha256-T/+/JxY9Oyf7e70yK8X/ZaENYbV0f0YmGYtaEmnvhgI="; # TODO
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
  ];

  checkInputs = [ netbox ];

  meta = {
    description = "Netbox Plugin for integration between Proxmox and Netbox";
    homepage = "https://github.com/netdevopsbr/netbox-proxbox";
    changelog = "https://github.com/netdevopsbr/netbox-proxbox/releases/tag/${src.rev}";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
