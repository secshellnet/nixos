{ self, ... }:
{
  getSystem = fqdn: self.nixosConfigurations."${fqdn}";
}
