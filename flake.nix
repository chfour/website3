{
  description = "chfour's website";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem flake-utils.lib.allSystems
      (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          selfPkgs = self.packages.${system};

          subsetWoff2 = with pkgs; (src: { pname ? src.pname + "-subset", unicodes, extraArgs ? [] }: src.overrideAttrs (old: {
            inherit pname;

            passthru = {
              unicodeRanges = unicodes;
            };

            nativeBuildInputs = (old.nativeBuildInputs or []) ++ (with python312Packages; [ fonttools brotli ]);
            postInstall = (old.postInstall or "") + ''
              for f in $out/share/fonts/woff2/*; do
                ${python312Packages.fonttools}/bin/fonttools subset "$f" \
                  --unicodes=${lib.escapeShellArg unicodes} \
                  ${lib.escapeShellArgs extraArgs} \
                  --flavor=woff2 --output-file="$f"
              done
            '';
          }));
        in {
          packages.inter-woff2 = pkgs.inter.overrideAttrs (old: {
            pname = "inter-woff2";
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/fonts/woff2
              cp web/InterVariable*.woff2 $out/share/fonts/woff2
              runHook postInstall
            '';
          });

          # lib.strings.concatStringsSep ", " packages.x86_64-linux.inter-fast.unicodeRanges
          # suboptimal the way it is atm. whatever
          packages.inter-fast = subsetWoff2 selfPkgs.inter-woff2 {
            pname = "inter-fast";
            unicodes = [
              # stolen from googel fonts and modified
              "U+0000-00FF" "U+0131" "U+0152-0153" "U+02BB-02BC"
              "U+02C6" "U+02DA" "U+02DC" "U+0304" "U+0308" "U+0329"
              "U+2000-206F" "U+20AC" "U+2122" "U+2191" "U+2193"
              "U+2212" "U+2215" "U+FEFF" "U+FFFD" "U+0394" "U+0398"
              "U+0104" "U+0106" "U+0118" "U+0141" "U+0143" "U+00D3"
              "U+015A" "U+0179" "U+017B" "U+0105" "U+0107" "U+0119"
              "U+0142" "U+0144" "U+00F3" "U+015B" "U+017A" "U+017C"
            ];
            extraArgs = [ "--layout-features+=cv10,zero,tnum" ];
          };

          packages.website-fonts = pkgs.stdenvNoCC.mkDerivation {
            name = "website-fonts"; # i tried pname => attribute 'name' missing ??

            phases = [ "installPhase" ]; # eh?

            installPhase = ''
              runHook preInstall

              mkdir -p $out

              # subset
              for f in ${selfPkgs.inter-fast}/share/fonts/woff2/*.woff2; do
                f_="''${f##*/}"
                cp "$f" "$out/''${f_%*.woff2}.fast.woff2"
              done
              # full
              for f in ${selfPkgs.inter-woff2}/share/fonts/woff2/*.woff2; do
                cp "$f" "$out"
              done

              runHook postInstall
            '';
          };

          packages.buildblog = pkgs.writeShellApplication {
            name = "buildblog";
            runtimeInputs = with pkgs; [ jq pandoc ];
            text = builtins.readFile ./buildblog.sh; # eh?
          };

          packages.autorebuild = pkgs.writeShellApplication {
            name = "autorebuild";
            runtimeInputs = with pkgs; [ selfPkgs.buildblog pkgs.inotify-tools ];
            text = ''
              [ -z "''${1+x}" ] && echo "usage: $0 blog-dir" && exit 1

              rebuild() {
                time buildblog "$1"
              }
              rebuild "$@"
              last=$(date +%s)
              inotifywait -r -m "$1" \
                -e modify -e create -e delete -e moved_to \
                --excludei '/index.html|highlighting.css' \
              | while read -r mod; do
                echo "$mod"
                now=$(date +%s)
                [ $((now - last)) -ge 2 ] && rebuild "$@" || echo '< 2s, skipping'
                last=$now
              done
            '';
          };

          packages.website = pkgs.stdenvNoCC.mkDerivation {
            name = "chfour-website";

            src = ./src;

            buildPhase = ''
              runHook preBuild

              ln -sf ${selfPkgs.website-fonts} ./fonts
              ${selfPkgs.buildblog}/bin/buildblog blog/
              rm blog/template_{index,page}.html
              sed -i \
                "s|/nix/store/VERY5p3c14lsecretv4luereplaceme0-chfour-website|$out|" \
                index.html

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/var/www
              cp -r * $out/var/www

              runHook postInstall
            '';
          };
        }
      );
}