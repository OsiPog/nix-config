flake: {
  serviceName,
  enforceSingleInstance ? false,
}: networkModule: {
  lib,
  config,
  ...
}: let
  inherit (builtins) filter length;
  inherit (flake.lib) mkModuleWithExtraMetaAttrs;
  inherit (lib) mkEnableOption mkIf mkOption types;
  inherit (lib.lists) optional;
in {
  assertions = optional enforceSingleInstance {
    assertion = length (filter (e: e.serviceName == serviceName) config.lib.network.allEnabledServices) == 1;
    message = "Network service '${serviceName}' must be enabled on exactly one host.";
  };

  network.sharedModules = [
    ({
      config,
      name,
      ...
    }: let
      cfg = config.services.${serviceName};
    in {
      imports = [
        (mkModuleWithExtraMetaAttrs {
            extraSpecialArgs = {
              inherit cfg;
              inherit name; # I think because we use imports instead of directly through sharedModules we lose the `name` extra argument.
            };
            mapExtraMetaAttr = name: content:
              if name == "optionsService"
              then {options.services.${serviceName} = content;}
              else if name == "configEnable"
              then {config = mkIf cfg.enable content;}
              else if name == "configService"
              then {config.services.${serviceName} = content;}
              else if name == "provideEnable"
              then {config.services.${serviceName}.provide = mkIf cfg.enable content;}
              else null;
          }
          networkModule)

        # options every network service has
        ({...}: {
          options.services.${serviceName} = {
            enable = mkEnableOption "the ${serviceName} network service on ${name}";
            id = mkOption {
              description = "ID of the server to decouple from host and service name. Can be referenced by config.lib.network.servicesById";
              type = types.str;
              default = name + "-" + serviceName;
            };
          };
        })

        # provide/require
        ({...}: let
          namedUserOptions = {
            display = mkOption {type = types.str;};
            email = mkOption {type = types.str;};
            secretName = mkOption {type = types.str;};
          };

          namedUserSubmodule = types.submodule {options = namedUserOptions;};

          secretsOpt = mkOption {
            description = "Same type as sops.secrets but trust me bro";
            default = {};
          };

          addressOpt = mkOption {
            type = types.functionTo types.str; # function: "domain"|"ip"|"host" -> str
          };

          interfaces = {
            ldap-server = let
              mkUser = {
                dn = mkOption {type = types.str;};
                secretName = mkOption {type = types.str;};
              };
            in
              mkOption {
                default = null;
                type = types.nullOr (types.submodule {
                  options = {
                    secrets = secretsOpt;
                    baseDN = mkOption {type = types.str;};
                    address = addressOpt;
                    users = {
                      admin = mkUser;
                      search = mkUser;
                      manage = mkUser;
                    };
                    attributes = {
                      email = mkOption {type = types.str;};
                      uid = mkOption {type = types.str;};
                      password = mkOption {type = types.str;};
                      memberof = mkOption {type = types.str;};
                      icon = mkOption {type = types.str;};
                    };
                  };
                });
              };

            ldap-clients = mkOption {
              default = [];
              type = types.listOf (types.submodule {
                options = {
                  secrets = secretsOpt;
                  groups = mkOption {
                    type = types.attrsOf types.attrs;
                    default = {};
                  };
                  users = mkOption {
                    type = types.attrsOf namedUserSubmodule;
                    default = {};
                  };
                  extraUserAttributes = mkOption {
                    default = {};
                    type = types.attrsOf (types.submodule {
                      options = {
                        dataType = mkOption {type = types.enum ["string" "integer" "boolean" "jpeg" "datetime"];};
                        editable = mkOption {type = types.bool;};
                        visible = mkOption {type = types.bool;};
                        multiple = mkOption {type = types.bool;};
                      };
                    });
                  };
                };
              });
            };

            mail-server = mkOption {
              default = null;
              type = types.nullOr (types.submodule {
                options.address = addressOpt;
              });
            };

            mail-clients = mkOption {
              default = [];
              type = types.listOf (types.submodule {
                options = {
                  secrets = secretsOpt;
                  mailAccount =
                    {
                      uid = mkOption {
                        description = "username of mail user";
                        type = types.str;
                      };
                    }
                    // namedUserOptions;
                };
              });
            };

            oidc-clients = mkOption {
              default = [];
              type = types.listOf (types.submodule {
                options = {
                  secrets = secretsOpt;
                  clientId = mkOption {type = types.str;};
                  clientName = mkOption {type = types.str;};
                  hashedClientSecret = mkOption {type = types.str;};
                  clientSecretName = mkOption {type = types.str;};
                  redirectUris = mkOption {type = types.listOf types.str;};
                  scopes = mkOption {
                    type = types.listOf types.str;
                    default = ["openid" "profile" "email"];
                  };
                  pkce = {
                    enabled = mkOption {
                      type = types.bool;
                      default = false;
                    };
                    method = mkOption {
                      type = types.enum ["plain" "S256"];
                      default = "S256";
                    };
                  };
                  idTokenClaims = mkOption {
                    type = types.listOf types.str;
                    default = [];
                  };
                };
              });
            };

            oidc-server = mkOption {
              default = null;
              type = types.nullOr (types.submodule {
                options.address = addressOpt;
              });
            };
          };
        in {
          options.services.${serviceName} = {
            provide = interfaces;
            require = interfaces;
          };
        })
      ];
    })
  ];
}
