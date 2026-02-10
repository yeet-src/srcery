{
  description = "srcery: the single nixpkgs pin for yeet-src";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }: {
    # srcery's job is to hold the canonical nixpkgs pin.
    # Other flakes (nix-darwin, project dev shells) follow this input.
  };
}
