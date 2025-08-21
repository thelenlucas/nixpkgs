{ stdenv
, fetchzip
, makeWrapper
, autoPatchelfHook
, lib
, waylandpp
, xorg
, libxcb
, fontconfig
, libxkbcommon
, libGL
}:

let
  system = stdenv.hostPlatform.system;

  urlSuffix = if system == "x86_64-linux" then
    "Linux64"
  else if system == "aarch64-linux" then
    "Linux_ARM64"
  else
    abort "Unsupported system ${system}";

  checksums = {
    x86_64-linux = "sha256-7Y7weRdkpY0DmDtzXFLhszZ2R93tYFgkPqHSh/+3VGY=";
    aarch64-linux = "sha256-OTDXrARFMgd2ubofcrFxrebUe39/QGJU5NafoF9U0Ag=";
  };

  vimbaXLibLocation = "$out/lib";

  binaries = {
    ListCameras_VmbC = "vimbax-list-cameras";
    ListFeatures_VmbC = "vimbax-list-features";
    VimbaXViewer = "VimbaXViewer";
    VimbaXFirmwareUpdater = "VimbaXFirmwareUpdater";
  };

in stdenv.mkDerivation rec {
  pname = "vimba-x";
  version = "2025-1";

  dontConfigure = true;

  src = fetchzip {
    url =
      "https://downloads.alliedvision.com/VimbaX/VimbaX_Setup-${version}-${urlSuffix}.tar.gz";
    sha256 = checksums.${system};
  };

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];

  buildInputs = [
    waylandpp.lib
    xorg.libSM
    xorg.libX11
    xorg.libxcb
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.libXinerama
    xorg.xcbutilwm
    libxcb
    fontconfig.lib
    libxkbcommon
    libGL
  ];

  installPhase = ''
    mkdir -p ${vimbaXLibLocation}/bin
    addAutoPatchelfSearchPath ${vimbaXLibLocation}/bin/
    cp -r $src/* ${vimbaXLibLocation}/ 

    find -H "${vimbaXLibLocation}/bin" -maxdepth 1 -type f -perm -111 -print0 \
    | while IFS= read -r -d ''' exe; do
        name=''${exe##*/}
        makeWrapper "$exe" "$out/bin/$name" \
            --set GENICAM_GENTL64_PATH "${vimbaXLibLocation}/cti"
    done 
  '';

  postFixup = let hook = "$out/nix-support/setup-hook";
  in ''
    mkdir -p $out/nix-support
    touch ${hook}
    cat > $out/nix-support/setup-hook << 'EOF'
      export GENICAM_GENTL64_PATH=${placeholder "out"}/lib/cti
    EOF
  '';
  
  strictDeps = true;

  meta = with lib; {
    description = "Allied Vision Vimba X SDK";
    homepage = "https://www.alliedvision.com/en/products/software/vimba-x-sdk/";
    license = licenses.unfree;
    mainProgram = "VimbaXViewer";
    platforms = platforms.linux;
    maintainers = [ maintainers.thelenlucas ];
    hydraPlatforms = [ ]; # Do not build on Hydra to comply with the license
  };
}