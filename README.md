# website3

not to be confused with: "web3", actually more like website3¾

this should reproduce the nix store path on the website:
`nix build github:chfour/website3#website --no-link --print-out-paths`

[this](https://github.com/chfour/nixos/blob/main/machines/fovps/services/caddy/default.nix)
is the other part of the code that makes this run and it is Cursed because of caching

run the following to serve everything locally:
`nix run nixpkgs#caddy -- file-server -l 0.0.0.0:8000 -a -r "$(nix build .#website.out --no-link --print-out-paths)/var/www"`
