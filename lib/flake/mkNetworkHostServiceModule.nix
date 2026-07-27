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
  inherit (lib) mkEnableOption mkIf mkOption types mkDefault;
  inherit (lib.lists) optional;
in {
  assertions =
    (optional enforceSingleInstance {
      assertion = length (filter (e: e.serviceName == serviceName) config.lib.network.allEnabledServices) == 1;
      message = "Network service '${serviceName}' must be enabled on exactly one host.";
    })
    ++ (let
      allServices = config.lib.network.allEnabledServices;
      thisServiceInstances = filter (e: e.serviceName == serviceName) allServices;
    in
      map (service: {
        assertion = length (filter (e: e.serviceCfg.id == service.serviceCfg.id) allServices) == 1;
        message = ''
          Network service ID '${service.serviceCfg.id}' must be unique network-wide, but is used by ${service.hostName}:${service.serviceName} and at least one other service.
          By default, a service's ID is it's name. That breaks when the same service runs on multiple hosts. Then use services.<name>.id to give each their own ID.
        '';
      })
      thisServiceInstances);

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
              default = serviceName;
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
                    adminGroup = mkOption {type = types.str;};
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
                    type = types.attrsOf (types.submodule {
                      options =
                        namedUserOptions
                        // {
                          groups = mkOption {
                            type = types.listOf types.str;
                          };
                        };
                    });
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
              type = types.listOf (types.submodule ({config, ...}: {
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
                  public = mkEnableOption "the oidc client to be public, thus using no secret.";
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
                  allowedGroup = mkOption {
                    type = types.str;
                    description = "LDAP group required to access this OIDC client.";
                  };
                  endpointAuthMethod = mkOption {
                    type = types.str;
                    description = "Which method is used to get the access token.";
                    default = "client_secret_basic";
                  };
                };
                config = {
                  allowedGroup = mkDefault config.clientId;
                };
              }));
            };

            oidc-server = mkOption {
              default = null;
              type = types.nullOr (types.submodule {
                options = {
                  address = addressOpt;
                  adminGroup = mkOption {type = types.str;};
                  name = mkOption {type = types.str;};
                };
              });
            };

            openai-api = mkOption {
              default = null;
              type = types.nullOr (types.submodule {
                options = {
                  url = mkOption {type = types.str;};
                  displayName = mkOption {type = types.str;};
                  secrets = secretsOpt;
                  apiKeySecretName = mkOption {type = types.str;};
                };
              });
            };

            tailscale-server = mkOption {
              default = null;
              type = types.nullOr (types.submodule {
                options = {
                  secrets = secretsOpt;
                  address = addressOpt;
                  ip4Space = mkOption {
                    type = types.str;
                  };
                  authKeySecretName = mkOption {
                    type = types.str;
                  };
                };
              });
            };

            tailscale-client = mkOption {
              default = null;
              type = types.nullOr (types.submodule {
                options = {
                  ip = mkOption {
                    type = types.str;
                  };
                  magicDns = mkOption {
                    type = types.str;
                  };
                };
              });
            };

            dns-server = mkOption {
              default = null;
              type = types.nullOr (types.submodule {
                options.address = addressOpt;
              });
            };

            dns-overrides = mkOption {
              default = [];
              type = types.listOf (types.submodule {
                options = {
                  query = mkOption {type = types.str;};
                  response = mkOption {type = types.str;};
                };
              });
            };

            backup-paths = mkOption {
              default = [];
              type = types.listOf (types.submodule {
                options = {
                  host = mkOption {
                    type = types.str;
                    description = "the host name of the host the path is located on. This assumes that the backup host has root ssh access on the hosts to be backupped.";
                    default = name;
                  };
                  path = mkOption {
                    type = types.pathWith {absolute = true;};
                    description = "An absolute path that should be backupped.";
                  };
                };
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
