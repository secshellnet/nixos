import contextlib

from django.contrib.auth.models import Group


def add_groups(response, user, backend, *args, **kwargs):
    with contextlib.suppress(KeyError):
        groups = response["groups"]

    # Add all groups from oauth token
    for g in groups:
        group, _ = Group.objects.get_or_create(name=g)
        group.user_set.add(user)


def remove_groups(response, user, backend, *args, **kwargs):
    try:
        groups = response["groups"]
    except KeyError:
        # Remove all groups if no groups in oauth token
        user.groups.clear()

    # Get all groups of user
    user_groups = [item.name for item in user.groups.all()]
    # Get groups of user which are not part of oauth token
    delete_groups = list(set(user_groups) - set(groups))

    # Delete non oauth token groups
    for g in delete_groups:
        group = Group.objects.get(name=g)
        group.user_set.remove(user)


def set_roles(response, user, backend, *args, **kwargs):
    try:
        groups = response["groups"]
        # Set roles is role (superuser or staff) is in groups
        user.is_superuser = "superusers" in groups
        user.is_staff = "staff" in groups
    except KeyError:
        user.is_superuser = False
        user.is_staff = False

    user.save()
