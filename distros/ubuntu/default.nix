{
  config,
  #
  runCommand,
  callPackage,
  lib,
  bubblewrap,
}:
runCommand "ubuntu-rootfs" {
  src = (callPackage ./generated.nix {}).rootfs.src;
} ''
  set -xe
  trap "set +x" ERR

  gzip -d $src -c > $out

  set +e
  tar -xpf $out
  set -e


  ${lib.concatMapStringsSep "\n" (c: ''
      ${bubblewrap}/bin/bwrap \
        --bind $PWD / \
        --uid 0 \
        --gid 0 \
        --setenv PATH /bin:/sbin:/usr/bin:/usr/sbin \
        -- ${c}
    '') [
      "useradd -m -N -g 100 -d ${config.home.homeDirectory} ${config.home.username}"
    ]}

  tee etc/sudoers.d/${config.home.username} <<EOF
  ${config.home.username} ALL=(ALL) NOPASSWD: ALL
  EOF

  ${lib.concatMapStringsSep "\n" (c: ''
      tar \
        -rvf $out \
        --numeric-owner \
        --hard-dereference \
        --mtime='@1' \
        ${c}
    '') [
      "--owner=0 --group=0 ./etc/passwd"
      "--owner=0 --group=0 --mode='u-w' ./etc/shadow"
      "--owner=0 --group=0 ./etc/group"
      "--owner=0 --group=0 --mode='u-w' ./etc/gshadow"
      "--owner=0 --group=0 ./etc/subuid"
      "--owner=0 --group=0 ./etc/subgid"
      "--owner=0 --group=0 ./etc/sudoers.d/${config.home.username}"
    ]}

  set +x
''
