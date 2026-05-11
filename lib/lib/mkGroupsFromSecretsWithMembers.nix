lib: secrets: members:
lib.mapAttrs' (_: secret: {
  name = secret.group;
  value = {inherit members;};
})
secrets
