# Same shape as the current disk: 2G EFI + LUKS2 holding btrfs subvolumes.
# WARNING: `disko --mode disko` erases the disk in identity.json (disk). Back up first (see README).
{ identity, ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = identity.disk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "root";
            # Read once, when disko formats the disk: tools/install.sh writes this
            # file (RAM only) from the password you type, then deletes it.
            passwordFile = "/tmp/disk-password";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes =
                let opts = [ "compress=zstd" "noatime" ];
                in {
                  "@" = { mountpoint = "/"; mountOptions = opts; };
                  "@home" = { mountpoint = "/home"; mountOptions = opts; };
                  "@nix" = { mountpoint = "/nix"; mountOptions = opts; };
                  "@log" = { mountpoint = "/var/log"; mountOptions = opts; };
                };
            };
          };
        };
      };
    };
  };
}
