# Netbox

## Open ID Connect
```nix
{
  secshell.netbox = {
    oidc.domain = "accounts.example.com";
    oidc.pubkey = "<pubkey>";
  };

  services.netbox.extraConfig = ''
    REMOTE_AUTH_DEFAULT_GROUPS = ["default"];
  '';
}
```

### Group management
To manage groups in NetBox custom
[social auth pipelines](https://python-social-auth.readthedocs.io/en/latest/pipeline.html) are required.
See [docs.goauthentik.io/integrations/services/netbox](https://docs.goauthentik.io/integrations/services/netbox/)
for more information.

```py
# pipeline.py
from netbox.authentication import Group

class AuthFailed(Exception):
    pass

def add_groups(response, user, backend, *args, **kwargs):
    try:
        groups = response['groups']
    except KeyError:
        pass

    # Add all groups from oAuth token
    for group in groups:
        group, created = Group.objects.get_or_create(name=group)
        # group.user_set.add(user) # For Netbox < 4.0.0
        user.groups.add(group) # For Netbox >= 4.0.0

def remove_groups(response, user, backend, *args, **kwargs):
    try:
        groups = response['groups']
    except KeyError:
        # Remove all groups if no groups in oAuth token
        user.groups.clear()
        pass

    # Get all groups of user
    user_groups = [item.name for item in user.groups.all()]
    # Get groups of user which are not part of oAuth token
    delete_groups = list(set(user_groups) - set(groups))

    # Delete non oAuth token groups
    for delete_group in delete_groups:
        group = Group.objects.get(name=delete_group)
        # group.user_set.remove(user) # For Netbox < 4.0.0
        user.groups.remove(group) # For Netbox >= 4.0.0


def set_roles(response, user, backend, *args, **kwargs):
    # Remove Roles temporary
    user.is_superuser = False
    user.is_staff = False
    try:
        groups = response['groups']
    except KeyError:
        # When no groups are set
        # save the user without Roles
        user.save()
        pass

    # Set roles is role (superuser or staff) is in groups
    user.is_superuser = True if 'superusers' in groups else False
    user.is_staff = True if 'staff' in groups else False
    user.save()
```

```nix
{
  services.netbox = {
    package = pkgs-unstable.netbox.overrideAttrs (old: {
      installPhase =
        old.installPhase
        + ''
          ln -s ${./pipeline.py} $out/opt/netbox/netbox/netbox/secshell_pipeline.py
        '';
    });

    extraConfig = ''
      SOCIAL_AUTH_PIPELINE = (
        ###################
        # Default pipelines
        ###################

        # Get the information we can about the user and return it in a simple
        # format to create the user instance later. In some cases the details are
        # already part of the auth response from the provider, but sometimes this
        # could hit a provider API.
        'social_core.pipeline.social_auth.social_details',

        # Get the social uid from whichever service we're authing thru. The uid is
        # the unique identifier of the given user in the provider.
        'social_core.pipeline.social_auth.social_uid',

        # Verifies that the current auth process is valid within the current
        # project, this is where emails and domains whitelists are applied (if
        # defined).
        'social_core.pipeline.social_auth.auth_allowed',

        # Checks if the current social-account is already associated in the site.
        'social_core.pipeline.social_auth.social_user',

        # Make up a username for this person, appends a random string at the end if
        # there's any collision.
        'social_core.pipeline.user.get_username',

        # Send a validation email to the user to verify its email address.
        # Disabled by default.
        # 'social_core.pipeline.mail.mail_validation',

        # Associates the current social details with another user account with
        # a similar email address. Disabled by default.
        # 'social_core.pipeline.social_auth.associate_by_email',

        # Create a user account if we haven't found one yet.
        'social_core.pipeline.user.create_user',

        # Create the record that associates the social account with the user.
        'social_core.pipeline.social_auth.associate_user',

        # Populate the extra_data field in the social record with the values
        # specified by settings (and the default ones like access_token, etc).
        'social_core.pipeline.social_auth.load_extra_data',

        # Update the user record with any changed info from the auth service.
        'social_core.pipeline.user.user_details',


        ###################
        # Custom pipelines
        ###################
        # Set authentik Groups
        'netbox.custom_pipeline.add_groups',
        'netbox.custom_pipeline.remove_groups',
        # Set Roles
        'netbox.custom_pipeline.set_roles'
      )
    '';
  };
}
```

## Napalm Plugin

```nix
{ config, ... }:
{
  sops.secrets."netbox/napalmPassword".owner = "netbox";

  secshell.netbox.plugin.napalm = true;

  services.netbox.extraConfig = ''
    PLUGINS_CONFIG = {
      "netbox_napalm_plugin": {
        "NAPALM_USERNAME": "napalm",
        "NAPALM_ARGS": {
          "netbox_default_ssl_params": True,
        },
      },
    }

    with open("${config.sops.secrets."netbox/napalmPassword".path}", "r") as file:
      PLUGINS_CONFIG["netbox_napalm_plugin"]["NAPALM_PASSWORD"] = file.readline()
  '';
}
```
