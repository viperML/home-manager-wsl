{
  config,
  #
  runCommand,
  callPackage,
  lib,
  bubblewrap,
}:
runCommand "alpine-rootfs" {
  src = (callPackage ./generated.nix {}).rootfs.src;
} ''
  set -xe
  trap "set +x" ERR

  gzip -d $src -c > $out

  tar -xpf $out

  ${lib.concatMapStringsSep "\n" (c: ''
      ${bubblewrap}/bin/bwrap \
        --bind $PWD / \
        --uid 0 \
        --gid 0 \
        --setenv PATH /bin:/sbin:/usr/bin:/usr/sbin \
        -- ${c}
    '') [
      "adduser --help"
      "adduser -h ${config.home.homeDirectory} -s /bin/sh -G users -D ${config.home.username}"
      "addgroup ${config.home.username} wheel"
    ]}

  cp -vfL ${./etc/profile} etc/profile


  ${lib.concatMapStringsSep "\n" (c: ''
      tar \
        -rvf $out \
        --numeric-owner \
        --hard-dereference \
        --mtime='@1' \
        ${c}
    '') [
      "--owner=0 --group=0 ./etc/passwd"
      "--owner=0 --group=42 ./etc/shadow"
      "--owner=0 --group=0 ./etc/group"
      "--owner=0 --group=0 ./etc/profile"
    ]}

  set +x
''
