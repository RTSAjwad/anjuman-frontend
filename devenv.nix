{ pkgs, ... }:

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
    # The Flutter 3.44.4 toolchain targets SDK 35/36 and jni targets 24.
    platforms.version = [ "35" ];
    buildTools.version = [ "35.0.0" ];
    cmake.version = [ "3.22.1" ];
    ndk.enable = true;
    googleAPIs.enable = true;
  };
}
