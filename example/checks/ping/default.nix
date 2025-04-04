{ ... }:
{
  name = "ping";

  globalTimeout = 60;

  defaults = {
    networking.useDHCP = false;
  };

  nodes = {
    machine1 = { };
    machine2 = { };
  };

  testScript = ''
    start_all()

    machine1.wait_for_unit("network-online.target")
    machine2.wait_for_unit("network-online.target")

    print(machine1.succeed("ping machine2"))
  '';
}
