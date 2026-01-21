{config, ...}: {
  users.groups.husk = {};

  users.users.opencloud.extraGroups = ["husk"];

  # Mount the husk drive as folder of the admin user
  fileSystems."${config.services.opencloud.stateDir}/storage/users/users/${config.services.lldap.settings.ldap_user_dn}/husk" = {
    device = "/mnt/husk";
    fsType = "fuse.bindfs";
  };
}
