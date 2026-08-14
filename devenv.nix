{ pkgs, lib, ... }:

{
  packages = with pkgs; [
    git
    jdk17
    gradle
    curl
    wget
    which
    unzip
    file
    rsync

    # Linux desktop build dependencies (for flutter run -d linux)
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
  ];

  android = {
    enable = true;
    flutter.enable = true;

    # Platform/build-tools versions that the project and its plugins need.
    # Flutter 3.44.4 targets compileSdk 36.
    platforms.version = [ "35" "36" ];
    buildTools.version = [ "36.0.0" "35.0.0" "28.0.3" ];
    cmake.version = [ "3.22.1" ];
    ndk.enable = true;
    googleAPIs.enable = true;
  };

  # Flutter's Gradle plugin needs to write into $FLUTTER_ROOT/packages/flutter_tools/gradle,
  # but the Nix store (including any derivation output) is immutable. Copy the Flutter SDK
  # into a project-local writable directory and point FLUTTER_ROOT there.
  enterShell = ''
    WRITABLE_FLUTTER="$PWD/.dart_tool/flutter-writable"

    if [ ! -f "$WRITABLE_FLUTTER/bin/flutter" ]; then
      echo "📦 Copying Flutter SDK to a writable location (first run only)..."
      mkdir -p "$WRITABLE_FLUTTER"
      rsync -a --no-owner --no-group "${pkgs.flutter}/" "$WRITABLE_FLUTTER/"
      chmod -R u+w "$WRITABLE_FLUTTER"

      # The nixpkgs Flutter SDK ships a broken placeholder .git (no commits),
      # which makes `flutter`'s git-based version detection crash. Remove it so
      # Flutter falls back to the `version` file (which contains "3.44.4").
      rm -rf "$WRITABLE_FLUTTER/.git"
    fi

    export FLUTTER_ROOT="$WRITABLE_FLUTTER"
    export DART_ROOT="$WRITABLE_FLUTTER/bin/cache/dart-sdk"
    export PATH="$WRITABLE_FLUTTER/bin:$PATH"

    # Rewrite local.properties to point at the writable Flutter SDK.
    # (devenv's sync-properties task ran before this and wrote the read-only path.)
    if [ -f android/local.properties ]; then
      sed -i "s|^flutter.sdk=.*|flutter.sdk=$WRITABLE_FLUTTER|" android/local.properties
    fi
  '';
}
