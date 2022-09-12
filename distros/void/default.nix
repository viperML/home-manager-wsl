{
  runCommand,
  callPackage,
}:
runCommand "void-rootfs" {
  src = (callPackage ./generated.nix {}).rootfs.src;
} ''
  xz -d $src -c > $out
''
