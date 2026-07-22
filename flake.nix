{
  description = "Anki Classroom Frontend - Flutter Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
            allowUnfree = true;
          };
        };

        # Android SDK with commonly needed platform components
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [
            "33"
            "34"
          ];
          abiVersions = [
            "x86_64"
            "arm64-v8a"
          ];
          includeNDK = true;
          includeEmulator = false;
          includeSystemImages = false;
        };
        androidSdk = androidComposition.androidsdk;

      in
      {
        devShells.default = pkgs.mkShell rec {
          name = "flutter-dev";

          buildInputs = with pkgs; [
            # Flutter and Dart
            flutter

            # Android SDK
            androidSdk
            jdk17

            # Linux desktop build dependencies
            cmake
            clang
            ninja
            pkg-config
            gtk3
            mesa
            libx11
            libxrandr
            libxinerama
            libxcursor
            libxi
            libxext
            libxfixes
            libxkbcommon
            libGL
            util-linux
            dbus
            fontconfig
            freetype
            harfbuzz
            expat
            libdrm
            wayland
            wayland-protocols
            vulkan-loader
            lz4
            libpng
            libjpeg

            # Development tools
            git
            curl
            wget
            which
            unzip
            file

            # Code formatting and analysis
            dart
          ];

          # Environment variables for Android SDK
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
          ANDROID_NDK_HOME = "${androidSdk}/libexec/android-sdk/ndk-bundle";

          # Java home for Android builds
          JAVA_HOME = pkgs.jdk17;

          # Flutter configuration
          FLUTTER_ROOT = pkgs.flutter;
          PUB_CACHE = ".dart_tool/pub-cache";

          shellHook = ''
            # Create local pub cache directory
            mkdir -p "$PUB_CACHE"

            # Prevent Flutter from trying to self-update (it's managed by Nix)
            export FLUTTER_GIT_URL=""

            # Pre-configure Flutter
            flutter config --no-analytics &>/dev/null || true

            echo ""
            echo "🚀 Flutter Development Environment"
            echo "=================================="
            echo "Flutter: $(flutter --version 2>/dev/null | head -1 || echo 'version info unavailable')"
            echo "Dart:    $(dart --version 2>/dev/null || echo 'version info unavailable')"
            echo "Java:    $(java --version 2>/dev/null | head -1 || echo 'version info unavailable')"
            echo ""
            echo "To see available devices:     flutter devices"
            echo "To run on Linux desktop:      flutter run -d linux"
            echo "To run on web:                flutter run -d chrome"
            echo ""
          '';
        };
      }
    );
}
