{ moduleNamespace, homeManager, ... }:
{
  bash = if homeManager then import ./home/bash.nix { inherit moduleNamespace; } else import ./nixOS/bash.nix { inherit moduleNamespace; };
  zsh = if homeManager then import ./home/zsh.nix { inherit moduleNamespace; } else import ./nixOS/zsh.nix { inherit moduleNamespace; };
  fish = if homeManager then import ./home/fish.nix { inherit moduleNamespace; } else import ./nixOS/fish.nix { inherit moduleNamespace; };
}
