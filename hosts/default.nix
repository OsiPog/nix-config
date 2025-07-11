self: let
  inherit (self.inputs.nixpkgs) lib;

  inherit (builtins) readDir attrNames listToAttrs;
  inherit (lib) pipe nixosSystem;
  inherit (lib.attrsets) attrsToList recursiveUpdate filterAttrs;
  inherit (lib.strings) concatLines;

  metaDefaults = {
    ip-address = "127.0.0.1";
    ssh = {
      public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB dummy@example.com";
      allow-connections-from = [];
    };
  };

  hosts = pipe "${self}/hosts" [
    # Get a list of hostnames
    readDir
    (filterAttrs (_: value: value == "directory"))
    attrNames

    # attr name is hostname and attr value is metadata
    (map (hostname: {
      name = hostname;
      value = recursiveUpdate metaDefaults (import "${self}/hosts/${hostname}/meta.nix");
    }))

    listToAttrs
  ];
in
  pipe hosts [
    attrsToList
    (map (e: {
      inherit (e) name;
      meta = e.value;
    })) # sensible names for attrs

    (map (host: {
      name = host.name;
      value = nixosSystem {
        specialArgs = {
          inherit self;
          inherit (self) inputs;
        };
        modules = [
          # Configuration for this host
          "${self}/hosts/${host.name}/configuration.nix"

          # Options shared among any configuration
          ./shared.nix

          # Options regarding secrets (sops nix) also shared among all
          ./secrets.nix

          # Set options based on hostname and other host metadata
          ({...}: {
            networking.hostName = host.name;
            facter.reportPath = "${self}/hosts/${host.name}/facter.json";
            sops.defaultSopsFile = "${self}/hosts/${host.name}/secrets.yaml";

            # enable openssh on port 22 if any connections are allowed
            services.openssh.enable = (host.meta.ssh.allow-connections-from) != [];
            # Add the public ssh keys from the allowed connections from meta attribute
            users.users.root.openssh.authorizedKeys.keys =
              map
              (other: hosts.${other}.ssh.public-key)
              host.meta.ssh.allow-connections-from;

            # Set up ssh keys, you should be able to ssh into another host using its hostname at all times
            programs.ssh.extraConfig = pipe hosts [
              attrNames
              (map (hostname: ''
                Host ${hostname}
                  HostName ${hostname}
                  IdentityFile /etc/ssh/id_ed25519
                  IdentitiesOnly Yes
              ''))
              concatLines
            ];

            # Add an entry for each host in /etc/hosts with their respective ip address
            networking.hosts = pipe hosts [
              attrsToList
              (map ({
                name,
                value,
              }: {
                name = value.ip-address;
                value = [name];
              }))
              listToAttrs
            ];
          })
        ];
      };
    }))

    listToAttrs
  ]
