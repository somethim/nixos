#!/usr/bin/env bash
# The flake app "install" (flake.nix). Run it in the official NixOS minimal ISO (README 4.1):
#   nix run --extra-experimental-features 'nix-command flakes' github:somethim/nixos#install [-- thinkpad|thinkpad-vm]
# The host is chosen by itself when you give none.
# flake.nix puts the Nord colours (NORD_*), the gum colours (GUM_*), PATH, SRC (the flake source),
# LOGO, ZONE_TAB and XKB_LST in front of this file.
# Without a terminal, or for a test, give every answer in an environment variable and the questions are skipped:
#   INSTALL_USER INSTALL_PASSWORD INSTALL_FULLNAME INSTALL_EMAIL INSTALL_HOSTNAME INSTALL_TIMEZONE
#   INSTALL_KEYBOARD INSTALL_DISK; INSTALL_YES=1 answers Yes to every confirmation.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exec sudo -E "$0" "$@"

log=/tmp/install.log
start=$(date +%s)
vm=false; systemd-detect-virt -q && vm=true
host=${1:-}
if [ -z "$host" ]; then if $vm; then host=thinkpad-vm; else host=thinkpad; fi; fi
case $host in thinkpad | thinkpad-vm) ;; *) echo "error: unknown host '$host' (use thinkpad or thinkpad-vm)" >&2; exit 1 ;; esac

# ---- Look ----
say() { gum style --margin "0 0 0 4" --foreground "$NORD_FG" "$@"; }
ok() { gum style --margin "0 0 0 4" --foreground "$NORD_GREEN" "✓ $*"; }
warn() { gum style --margin "0 0 0 4" --foreground "$NORD_YELLOW" "! $*"; }
die() { gum style --margin "0 0 0 4" --foreground "$NORD_RED" --bold "✗ $*" >&2; exit 1; }
# The lambda snowflake with a gradient: frost blues to purple, one colour for each line.
logo() {
  echo
  local n i col stops=("$NORD_CYAN2" "$NORD_CYAN" "$NORD_BLUE" "$NORD_MAGENTA") line
  n=$(wc -l < "$LOGO")
  i=0
  while IFS= read -r line; do
    if [ "${TERM:-}" = linux ]; then
      col=${stops[i * 4 / n]}
      # The console font has no quarter blocks: use half and full blocks.
      line=$(sed -E 's/(▖|▗)/▄/g; s/(▘|▝)/▀/g; s/(▙|▛|▜|▟|▚|▞)/█/g' <<< "$line")
    else
      col=$(awk -v i="$i" -v n="$n" -v s="$NORD_CYAN2 $NORD_CYAN $NORD_BLUE $NORD_MAGENTA" 'BEGIN {
        split(s, c, " "); t = i / (n - 1) * 3; k = int(t); if (k > 2) k = 2; f = t - k
        for (j = 0; j < 3; j++) { a = strtonum("0x" substr(c[k + 1], 2 + 2 * j, 2)); b = strtonum("0x" substr(c[k + 2], 2 + 2 * j, 2)); r = r sprintf("%02x", a + (b - a) * f) }
        print "#" r }')
    fi
    gum style --foreground "$col" "    $line"
    i=$((i + 1))
  done < "$LOGO"
  echo
}
heading() { gum style --margin "0 0 0 4" --foreground "$NORD_BLUE" --bold "$@"; echo; }
# A new screen: clear it and draw the logo. A small console (under 40 lines) shows the text only.
screen() { clear; if [ "$(tput lines 2>/dev/null || echo 25)" -ge 40 ]; then logo; fi; }

# ask VAR "Question" DEFAULT [REGEX] [--password]: the answer comes from INSTALL_<VAR>, or from gum input.
ask() {
  local var=$1 question=$2 default=$3 re=${4:-.} pass=${5:-} env=INSTALL_${1#F_} value
  while :; do
    if [ -n "${!env:-}" ]; then value=${!env}
    else value=$(gum input ${pass:+--password} --header "$question" --value "$default" --placeholder "$default") || exit 1
      [ -n "$value" ] || value=$default
    fi
    if [[ $value =~ $re ]]; then printf -v "$var" '%s' "$value"; return; fi
    [ -z "${!env:-}" ] || die "$env is not valid"
    warn "That value is not valid. Try again."
  done
}
# confirm "Question" [yes-label] [no-label]
confirm() { [ -n "${INSTALL_YES:-}" ] || gum confirm "$1" ${2:+--affirmative "$2"} ${3+--negative "$3"}; }

screen
heading "Let's install NixOS on this computer ($host)"

# ---- The source: a writable copy of this flake, with a git repository (the flake needs one) ----
work=$(mktemp -d /tmp/install-laptop.XXXXXX)
trap 'rm -rf "$work"' EXIT
# The store files are read-only: keep the executable bits, add the write bit.
cp -rT --no-preserve=ownership "$SRC" "$work"
chmod -R u+w "$work"
git -C "$work" init -q -b master
git -C "$work" remote add origin https://github.com/somethim/nixos.git
git -C "$work" add -A
git -C "$work" -c user.name=installer -c user.email=installer@localhost commit -q -m "chore(install): initial checkout"
tree=$work
ok "Configuration copied"

# ---- The network: the installer downloads the newest inputs and the packages ----
net() { curl -sSf -o /dev/null --max-time 5 https://cache.nixos.org/nix-cache-info 2>/dev/null; }
if ! net; then
  [ -z "${INSTALL_YES:-}" ] || die "No network."
  warn "No network. Select a network."
  nmtui || true
  net || die "No network. Connect one and run the installer again."
fi
ok "Network works"

# ---- The user ----
id=$tree/identity.json
def() { jq -r "$1" "$id"; }
d_user=$(def .user) d_name=$(def .fullName) d_email=$(def .email) d_tz=$(def .timeZone) d_kb=$(def .keyboard)
d_host=$(jq -r --arg h "$host" '.hostName // $h' "$id")
# A list for gum filter with the current value first, so Enter keeps it.
pick() { # VAR "Question" DEFAULT LIST-COMMAND-OUTPUT-ON-STDIN
  local var=$1 question=$2 default=$3 env=INSTALL_${1#F_} list value
  list=$(cat)
  if [ -n "${!env:-}" ]; then printf -v "$var" '%s' "${!env}"; return; fi
  value=$({ grep -m1 "^$default\b" <<< "$list" || true; grep -v "^$default\b" <<< "$list"; } |
    gum filter --header "$question (type to search, Enter keeps $default)") || exit 1
  printf -v "$var" '%s' "${value%% *}"
}
echo
say "Let's set up your user account..."
echo
while :; do
  ask F_USER "Username" "$d_user" '^[a-z_][a-z0-9_-]*$'
  while :; do
    ask F_PASSWORD "Password (also the disk password)" "" '.' --password
    pw=$F_PASSWORD
    if [ -n "${INSTALL_PASSWORD:-}" ]; then break; fi
    ask F_PASSWORD "Password again" "" '.' --password
    [ "$F_PASSWORD" = "$pw" ] && break
    warn "The passwords are not the same. Try again."
  done
  ask F_FULLNAME "Full name" "$d_name"
  ask F_EMAIL "Email address" "$d_email" '^[^@ ]+@[^@ ]+$'
  ask F_HOSTNAME "Hostname" "$d_host" '^[a-zA-Z0-9][a-zA-Z0-9-]*$'
  pick F_TIMEZONE "Time zone" "$d_tz" < <(grep -v "^#" "$ZONE_TAB" | cut -f3 | sort)
  pick F_KEYBOARD "Keyboard layout" "$d_kb" < <(awk '/^! layout/ {f = 1; next} /^!/ {f = 0} f && NF' "$XKB_LST" | sed 's/^ *//')
  screen
  { printf 'Field|Value\n'
    printf 'Username|%s\nPassword|***\nFull name|%s\nEmail|%s\nHostname|%s\nTimezone|%s\nKeyboard|%s\n' \
      "$F_USER" "$F_FULLNAME" "$F_EMAIL" "$F_HOSTNAME" "$F_TIMEZONE" "$F_KEYBOARD"; } |
    column -t -s'|' | gum style --margin "0 0 0 4" --border normal --border-foreground "$NORD_BLUE" --padding "0 2"
  echo
  if confirm "Does this look right?" "Yes" "No, change it"; then break; fi
  d_user=$F_USER d_name=$F_FULLNAME d_email=$F_EMAIL d_host=$F_HOSTNAME d_tz=$F_TIMEZONE d_kb=$F_KEYBOARD
  screen
  say "Let's set up your user account..."
  echo
  unset INSTALL_PASSWORD INSTALL_USER INSTALL_FULLNAME INSTALL_EMAIL INSTALL_HOSTNAME INSTALL_TIMEZONE INSTALL_KEYBOARD
done

# ---- The disk: the VM disk is /dev/vda; the laptop has its own disk, never the installer medium ----
disk=${INSTALL_DISK:-$(def .disk)}
if $vm; then
  disk=/dev/vda
elif [ -z "${INSTALL_DISK:-}" ]; then
  isodisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /iso)" 2>/dev/null || true)
  mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL,TYPE,RM | awk -v u="/dev/$isodisk" '$(NF-1) == "disk" && $NF == 0 && $1 != u {print}')
  [ "${#disks[@]}" -gt 0 ] || die "No internal disk found."
  if [ "${#disks[@]}" -gt 1 ]; then
    disk=$(printf '%s\n' "${disks[@]}" | gum choose --header "Install on which disk?") || exit 1
  else
    disk=${disks[0]}
  fi
  disk=${disk%% *}
fi
screen
gum style --margin "0 0 0 4" --foreground "$NORD_RED" --border double --border-foreground "$NORD_RED" --padding "0 2" --bold \
  "WARNING: everything on $disk will be erased." "This cannot be undone."
echo
confirm "Erase $disk and install NixOS?" "Erase and install" "Cancel" || { warn "Cancelled. Nothing was changed."; exit 1; }

# The values go into the checkout that is installed. The password is never written there.
jq -n --arg user "$F_USER" --arg fullName "$F_FULLNAME" --arg email "$F_EMAIL" --arg hostName "$F_HOSTNAME" \
  --arg timeZone "$F_TIMEZONE" --arg keyboard "$F_KEYBOARD" --arg disk "$disk" \
  '{$user, $fullName, $email, $hostName, $timeZone, $keyboard, $disk}' > "$id"

# ---- The install: tools/install.sh does the work; this shows its steps ("==> ..." lines in the log) ----
echo
: > "$log"
INSTALL_PASSWORD=$F_PASSWORD INSTALL_YES=1 bash "$work/tools/install.sh" "$host" > "$log" 2>&1 &
pid=$!
unset F_PASSWORD pw INSTALL_PASSWORD
current=
spin='|/-\'
n=0
while kill -0 "$pid" 2>/dev/null; do
  step=$(grep '^==> ' "$log" | tail -1 | cut -c5- || true)
  if [ "$step" != "$current" ]; then
    [ -z "$current" ] || { printf '\r\033[K'; ok "$current"; }
    current=$step
  fi
  printf '\r\033[K    %s %s (%dm %02ds)' "${spin:n++%${#spin}:1}" "${current:-Starting}" $((($(date +%s) - start) / 60)) $((($(date +%s) - start) % 60))
  sleep 0.3
done
printf '\r\033[K'
if wait "$pid"; then
  [ -z "$current" ] || ok "$current"
else
  gum style --margin "0 0 0 4" --foreground "$NORD_RED" --bold "✗ The install failed. The last lines of $log:"
  tail -n 25 "$log"
  exit 1
fi

# ---- The end ----
secs=$(($(date +%s) - start))
screen
gum style --margin "0 0 0 4" --foreground "$NORD_GREEN" --bold "Installed in $((secs / 60))m $((secs % 60))s"
echo
gum style --margin "0 0 0 4" --foreground "$NORD_YELLOW" --bold "Remember to remove the USB drive!"
echo
if $vm; then label="Power off now"; cmd=poweroff; else label="Reboot now"; cmd=reboot; fi
confirm "Installation done." "$label" "" || true
"$cmd"
