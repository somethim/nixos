#!/usr/bin/env bash
# Automatic, headless test of the laptop installation (README 4.1 and 4.2) on the host
# thinkpad-vm, on a new empty virtual disk. It needs no key presses. Run it as ONE heavy job.
# The caller takes the lock; this script does not:
#   flock /tmp/claude-1000/heavy.lock nice -n 10 tools/vm-install-test.sh
#
# It boots the OFFICIAL NixOS minimal ISO (the file VM_ISO, default: the newest
# ~/.cache/nixos-minimal-*.iso; the script never writes to it) with the network on, and runs the flake app
# from this working tree (not from GitHub, because the new commit is not pushed yet).
# Steps (all in the Nix container, like tools/eval.sh):
#   1. Export the tracked files of this repository to the scratch directory (9p share "cfg").
#   2. Boot the kernel and initrd of the ISO in QEMU/KVM (no window; the ISO has a serial console
#      entry in its boot menu, this test gives the same kernel options at once). On the serial console:
#      mount the share and run `nix run path:/cfg#install` with every answer in INSTALL_* variables.
#      The app updates flake.lock, partitions the disk, installs and copies the checkout.
#   3. Boot the installed disk, type the disk password, wait for the desktop, take screenshots
#      and keep the serial log (the journal is forwarded to the serial port on thinkpad-vm).
#   4. Check the log. Exit status is not zero when a check fails.
# Output: tools/out/install-*.png, tools/out/install-installer.log, tools/out/install-serial.log.
# Scratch directory (disk, export): ${VM_TEST_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/nixos-config-install-test}.
# Expected: 40 to 120 minutes (the system is built from cache.nixos.org), 6 CPUs and 10 GB RAM for QEMU,
# 25 to 45 GB in the scratch directory (delete it afterwards). The test password is fixed and is not a real password.
set -eu
PASSWORD=vmtest-pass

if [ "${1:-}" != --inner ]; then
  cd "$(dirname "$0")/.."
  repo=$PWD
  scratch=${VM_TEST_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/nixos-config-install-test}
  case $scratch in */VMs/*) echo "error: refusing to use $scratch" >&2; exit 1 ;; esac
  mkdir -p "$scratch" tools/out
  git add -A
  iso=${VM_ISO:-$(find "$HOME/.cache" -maxdepth 1 -name 'nixos-minimal-*-x86_64-linux.iso' | sort | tail -1)}
  [ -f "$iso" ] || { echo "error: put the official nixos-minimal ISO in ~/.cache or set VM_ISO" >&2; exit 1; }
  # The tracked files of the working tree, as the flake source of the app.
  rm -rf "$scratch/cfg"; mkdir -p "$scratch/cfg"
  git ls-files -z | xargs -0 cp --parents -t "$scratch/cfg"
  name=vm-install-test-$$
  trap 'docker kill "$name" >/dev/null 2>&1 || true' EXIT INT TERM
  echo "test password: $PASSWORD"
  docker run --rm --init --name "$name" --device /dev/kvm -v nixstore:/nix \
    -v "$repo":/work/nixos-config -v "$scratch":/w -v "$repo/tools/out":/out -v "$iso":/w-iso/installer.iso:ro \
    -e PASSWORD="$PASSWORD" nixos/nix:latest bash /work/nixos-config/tools/vm-install-test.sh --inner
  exit
fi

# ---- Inside the container ----
export NIX_CONFIG="experimental-features = nix-command flakes
max-jobs = 2
cores = 4"
git config --global --add safe.directory /work/nixos-config
git config --global --add safe.directory /work/nixos-config/.git
cd /work/nixos-config

if [ "${2:-}" != --vm ]; then
  trap 'chown -R 1000:1000 /out /w flake.lock 2>/dev/null || true' EXIT
  # The tools and the UEFI firmware come from the pinned nixpkgs.
  ovmf=$(nix build --no-link --print-out-paths --inputs-from . nixpkgs#OVMF.fd)
  OVMF=$ovmf exec nix shell --inputs-from . nixpkgs#qemu nixpkgs#expect nixpkgs#socat nixpkgs#imagemagick nixpkgs#libarchive nixpkgs#gnused \
    -c bash /work/nixos-config/tools/vm-install-test.sh --inner --vm
fi

# ---- Inside the container, with qemu and expect ----
trap 'pkill -f qemu-system-x86_64 2>/dev/null || true; chown -R 1000:1000 /out /w /work/nixos-config/flake.lock 2>/dev/null || true' EXIT
cd /w
# Kernel, initrd and kernel options of the first boot entry of the ISO, plus the serial console.
rm -rf /w/iso; mkdir /w/iso
bsdtar -xf /w-iso/installer.iso -C /w/iso EFI/BOOT/grub.cfg 'boot/nix/store/*'
kernel=$(grep -m1 -E '^ *linux ' /w/iso/EFI/BOOT/grub.cfg | sed -E 's/^ *linux ([^ ]+).*/\1/')
initrd=$(grep -m1 -E '^ *initrd ' /w/iso/EFI/BOOT/grub.cfg | sed -E 's/^ *initrd ([^ ]+).*/\1/')
append=$(grep -m1 -E '^ *linux ' /w/iso/EFI/BOOT/grub.cfg | sed -E 's/^ *linux [^ ]+ //; s/\$\{isoboot\} *//')
rm -f disk.qcow2 efivars.fd inst.sock boot.sock mon.sock
qemu-img create -q -f qcow2 disk.qcow2 60G
cp "$OVMF/FV/OVMF_VARS.fd" efivars.fd; chmod u+w efivars.fd
# The target disk is the first virtio disk (/dev/vda, as hosts/thinkpad-vm/default.nix wants).
qemu_base() { # $1 serial log, $2 serial socket, rest: extra
  local log=$1 sock=$2; shift 2
  qemu-system-x86_64 -name thinkpad-vm-test -enable-kvm -machine q35 -cpu host -smp 6 -m 10G \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF/FV/OVMF_CODE.fd" \
    -drive if=pflash,format=raw,file=/w/efivars.fd \
    -drive file=/w/disk.qcow2,if=virtio,discard=unmap \
    -device virtio-vga -display none -device virtio-rng-pci \
    -nic user,model=virtio-net-pci \
    -chardev socket,id=ser,path="$sock",server=on,wait=on,logfile="$log" -serial chardev:ser \
    -monitor unix:/w/mon.sock,server=on,wait=off "$@" &
}

export LOGIN_TIMEOUT=900
# ---- Phase 1: the installer ----
: > /out/install-installer.log
qemu_base /out/install-installer.log /w/inst.sock \
  -cdrom /w-iso/installer.iso -kernel "/w/iso$kernel" -initrd "/w/iso$initrd" -append "$append console=ttyS0,115200" \
  -virtfs local,path=/w/cfg,mount_tag=cfg,security_model=none,readonly=on
qpid=$!
inst_rc=0
expect -f - <<'EXP' || inst_rc=$?
set timeout 900
log_user 0
while {![file exists /w/inst.sock]} { after 500 }
spawn socat - UNIX-CONNECT:/w/inst.sock
proc fail {msg} { puts "FAIL (installer): $msg"; exit 1 }
# Run a command and wait for it to end; $to is the time limit in seconds.
proc run {cmd {to 60}} {
  global expect_out
  send -- "$cmd; echo RC=\$?\r"
  expect -timeout $to -re {RC=([0-9]+)\r*\n} {} timeout { fail "time out: $cmd" }
  if {$expect_out(1,string) != 0} { fail "$cmd ended with $expect_out(1,string)" }
}
# The ISO logs in as user nixos on the serial console.
send "\r"
expect -timeout 600 -re {nixos@nixos:[^\r\n]*\]\$} {} timeout { fail "no installer prompt" }
run "stty cols 200"
run "sudo mkdir -p /cfg && sudo mount -t 9p -o trans=virtio,ro cfg /cfg" 120
# The test answers no questions: it gives every answer in INSTALL_* variables (tools/install-laptop.sh).
# The values differ from the repository, so the test shows that they reach the system.
set vars "INSTALL_YES=1 INSTALL_PASSWORD=$env(PASSWORD) INSTALL_USER=somethim INSTALL_FULLNAME='Test User' INSTALL_EMAIL=test@example.com INSTALL_HOSTNAME=test-vm INSTALL_TIMEZONE=Europe/Berlin INSTALL_KEYBOARD=de"
send "$vars nix run --extra-experimental-features 'nix-command flakes' path:/cfg#install\r"
expect -timeout 1800 "Let's install NixOS on this computer (thinkpad-vm)" {} timeout { fail "host was not chosen as thinkpad-vm" }
# The last screen shows the time; the VM then powers off by itself.
expect -timeout 9000 -re {Installed in [0-9]+m} {} -re {The install failed} { after 15000; fail "install-laptop reported a failure" } -re {nixos@nixos:[^\r\n]*\]\$} { fail "install-laptop ended without Installed in" } timeout { fail "install-laptop did not finish" }
expect -timeout 300 eof {} timeout { fail "no poweroff" }
puts "installer finished"
EXP
# On a failure the VM is still up: stop it, or wait never returns.
if [ "$inst_rc" -ne 0 ]; then kill "$qpid" 2>/dev/null || true; fi
wait "$qpid" 2>/dev/null || true
if [ "$inst_rc" -ne 0 ]; then echo "FAIL: installer phase"; exit 1; fi

# ---- Phase 2: first boot from the installed disk ----
rm -f /w/mon.sock /w/boot.sock
: > /out/install-serial.log
qemu_base /out/install-serial.log /w/boot.sock
qpid=$!
# Same way as tools/vm-screenshot.sh: the monitor writes PPM; keep the socket open until it is done.
shot() { { echo "screendump /w/$1.ppm"; sleep 2; } | socat - UNIX-CONNECT:/w/mon.sock >/dev/null
         magick /w/$1.ppm /out/$1.png && rm -f /w/$1.ppm; }
expect -f - <<'EXP'
set timeout 600
log_user 0
while {![file exists /w/boot.sock]} { after 500 }
spawn socat - UNIX-CONNECT:/w/boot.sock
expect -nocase -re {passphrase[^\r\n]*:} {} timeout { puts "FAIL: no disk password prompt"; exit 1 }
send "$env(PASSWORD)\r"
# The session starts by itself (autologin); keep reading the serial line for 120 s.
expect -timeout 120 eof {} timeout {}
EXP
shot install-1-desktop
sleep 30; shot install-2-desktop-later
echo quit | socat - UNIX-CONNECT:/w/mon.sock >/dev/null || true
wait "$qpid" 2>/dev/null || true

# ---- Phase 3: checks ----
set +e
fails=0
check() { # name, ok(0/1), detail
  if [ "$2" -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1  $3"; fails=$((fails + 1)); fi
}
inst=/out/install-installer.log log=/out/install-serial.log
has() { grep -qaiE "$2" "$1"; }
has "$inst" "Installed in [0-9]+m";                    check "installer finished (Installed in ...)" $? ""
u=$(grep -an '✓ Updating the flake inputs' "$inst" | head -1 | cut -d: -f1); p=$(grep -an '✓ Partitioning' "$inst" | head -1 | cut -d: -f1)
[ -n "$u" ] && [ -n "$p" ] && [ "$u" -lt "$p" ];       check "flake inputs updated before disko" $? "update line '$u', disko line '$p'"
has "$log" 'wayland-wm@|Hyprland' && has "$log" 'desktop-shell'; check "graphical session (uwsm/Hyprland, desktop-shell)" $? ""
! has "$log" 'Failed to start';                        check "no failed units" $? "$(grep -aiE 'Failed to start' "$log" | head -5)"
! has "$log" 'first-run';                              check "first-run step skipped (marker present)" $? "$(grep -aiE 'first-run' "$log" | head -3)"
has "$log" 'Started SSH authentication agent'; check "ssh-agent.service started" $? ""
! has "$log" 'gcr-ssh-agent';                          check "no gcr ssh agent" $? ""
has "$log" 'Activating defaultKeyring|gnome-keyring';  check "keyring activation ran" $? ""
has "$log" "Using system hostname 'test-vm'";                              check "host name from the questions (test-vm)" $? ""
[ -s /out/install-1-desktop.png ];                     check "screenshot saved" $? ""
echo "== $fails check(s) failed. Files: tools/out/install-*.png, install-serial.log, install-installer.log"
[ "$fails" -eq 0 ]
