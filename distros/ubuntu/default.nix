{
  runCommand,
  callPackage,
}:
runCommand "ubuntu-rootfs" {
  src = (callPackage ./generated.nix {}).rootfs.src;
} ''
  gzip -d $src -c > $out
''
