#!/usr/bin/env bash
sudo nixos-container start agents
sudo nixos-container run agents -- bash -c 'cd /data;su claude'
