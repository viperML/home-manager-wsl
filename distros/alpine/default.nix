{
  runCommand,
  callPackage,
}:
runCommand "alpine-rootfs" {
  src = (callPackage ./generated.nix {}).rootfs.src;
} ''
  gzip -d $src -c > $out
''
