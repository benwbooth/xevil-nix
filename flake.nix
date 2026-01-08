{
  description = "XEvil - A side-view, single or network-multiplayer, fast-action, kill-everything game";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Create a merged font directory with both fonts and aliases
        xevilFonts = pkgs.runCommand "xevil-fonts" {
          nativeBuildInputs = [ pkgs.xorg.mkfontscale ];
        } ''
          mkdir -p $out/share/fonts/X11/misc
          # Copy all font files
          cp ${pkgs.xorg.fontmiscmisc}/share/fonts/X11/misc/*.pcf.gz $out/share/fonts/X11/misc/
          # Copy font aliases
          cp ${pkgs.xorg.fontalias}/share/fonts/X11/misc/fonts.alias $out/share/fonts/X11/misc/
          # Regenerate fonts.dir with mkfontdir
          cd $out/share/fonts/X11/misc
          ${pkgs.xorg.mkfontscale}/bin/mkfontdir
        '';

        xevil = pkgs.stdenv.mkDerivation rec {
          pname = "xevil";
          version = "2.02r-unstable-2023-10-28";

          src = pkgs.fetchFromGitHub {
            owner = "lvella";
            repo = "xevil";
            rev = "9ca85059d5195be0eb15e107de3bb9d1b49e5f99";
            hash = "sha256-LOYsIBIOX0rOY97uU61HXM4wro92f6DDtVoJShOvGpI=";
          };

          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.makeWrapper
            pkgs.imagemagick
            pkgs.copyDesktopItems
          ];

          desktopItems = [
            (pkgs.makeDesktopItem {
              name = "xevil";
              exec = "xevil";
              icon = "xevil";
              desktopName = "XEvil";
              comment = "A side-view, fast-action, kill-everything game";
              categories = [ "Game" "ActionGame" ];
              keywords = [ "game" "action" "multiplayer" ];
            })
          ];

          buildInputs = [
            pkgs.xorg.libX11
            pkgs.xorg.libXpm
          ];

          # The game requires the 9x15 bitmap font at runtime
          propagatedBuildInputs = [
            pkgs.xorg.fontmiscmisc
          ];

          makeFlags = [
            "CC=${pkgs.stdenv.cc.targetPrefix}cc"
            "CXX=${pkgs.stdenv.cc.targetPrefix}c++"
          ];

          # No configure script, just make
          dontConfigure = true;

          # Fix hardcoded /bin/uname and /usr/bin/uname paths
          postPatch = ''
            substituteInPlace cmn/utils.cpp \
              --replace-fail '"/bin/uname"' '"${pkgs.coreutils}/bin/uname"' \
              --replace-fail '"/usr/bin/uname"' '"${pkgs.coreutils}/bin/uname"'
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            install -Dm755 x11/REDHAT_LINUX/xevil $out/bin/.xevil-unwrapped
            install -Dm755 x11/REDHAT_LINUX/serverping $out/bin/xevil-serverping

            mkdir -p $out/share/doc/xevil
            cp -r instructions/* $out/share/doc/xevil/
            install -Dm644 compiling.html $out/share/doc/xevil/
            install -Dm644 readme.txt $out/share/doc/xevil/

            # Convert XPM icon to PNG and install at various sizes
            for size in 16 32 48 64 128; do
              mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
              convert x11/bitmaps/ui/xevil_icon.xpm -resize ''${size}x''${size} \
                $out/share/icons/hicolor/''${size}x''${size}/apps/xevil.png
            done

            runHook postInstall
          '';

          # Wrap the binary to ensure the font path is set
          postFixup = let
            fontPath = "${xevilFonts}/share/fonts/X11/misc";
          in ''
            makeWrapper $out/bin/.xevil-unwrapped $out/bin/xevil \
              --run "${pkgs.xorg.xset}/bin/xset +fp ${fontPath} 2>/dev/null || true" \
              --run "${pkgs.xorg.xset}/bin/xset fp rehash 2>/dev/null || true" \
              --prefix PATH : "${pkgs.coreutils}/bin"
          '';

          meta = with pkgs.lib; {
            description = "A side-view, single or network-multiplayer, fast-action, kill-everything game";
            homepage = "https://www.xevil.com/";
            license = licenses.gpl2Only;
            maintainers = [ ];
            platforms = platforms.linux;
            mainProgram = "xevil";
          };
        };

      in {
        packages = {
          default = xevil;
          xevil = xevil;
        };

        apps.default = {
          type = "app";
          program = "${xevil}/bin/xevil";
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ xevil ];
        };
      }
    );
}
