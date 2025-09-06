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

          packages.website = pkgs.stdenvNoCC.mkDerivation {
            name = "chfour-website";

            src = ./src;

            phases = [ "installPhase" ];

            installPhase = ''
              runHook preInstall

              mkdir -p $out

              cp -r $src/* $out/
              ln -sf ${selfPkgs.website-fonts} $out/fonts

              runHook postInstall
            '';
          };
        }
      );
}