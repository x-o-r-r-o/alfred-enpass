#!/bin/zsh
# Capture README screenshots of the installed workflow using the demo vault in tools/demo/vault,
# so none of your own entries appear. Your configuration is restored afterwards.
# Run it from Terminal: it needs permission to control Alfred and to record the screen.
# Usage: tools/demo/shoot.sh [fields]   (fields: only retake images/fields.png)
here="${0:A:h}"
root="${here:h:h}"
out="$root/images"
helper="${TMPDIR:-/tmp/}alfred_window"
bundle="com.x-o-r-r-o.alfred.enpass"
demo_account="de300000-0000-4000-8000-00000000de30"   # vault_uuid of tools/demo/vault
prefs="$(python3 -c "import json,pathlib;print(json.loads((pathlib.Path.home()/'Library/Application Support/Alfred/prefs.json').read_text())['current'])")/workflows"

tell() { osascript -e "tell application id \"com.runningwithcrayons.Alfred\" to $1" }
wf_dir="$(grep -l "<string>$bundle</string>" "$prefs"/*/info.plist 2>/dev/null | head -1)"
[[ -n "$wf_dir" ]] || { echo "Install the workflow first (open dist/Enpass.alfredworkflow)" >&2; exit 1; }
wf_dir="${wf_dir:h}"
old_vault="$(/usr/libexec/PlistBuddy -c 'Print :vault_path' "$wf_dir/prefs.plist" 2>/dev/null)"
old_keyfile="$(/usr/libexec/PlistBuddy -c 'Print :keyfile_path' "$wf_dir/prefs.plist" 2>/dev/null)"

restore() {
  if [[ -n "$old_vault" ]]; then tell "set configuration \"vault_path\" to value \"$old_vault\" in workflow \"$bundle\""
  else tell "remove configuration \"vault_path\" in workflow \"$bundle\""; fi
  if [[ -n "$old_keyfile" ]]; then tell "set configuration \"keyfile_path\" to value \"$old_keyfile\" in workflow \"$bundle\""
  else tell "remove configuration \"keyfile_path\" in workflow \"$bundle\""; fi
  security delete-generic-password -s "$bundle" -a "$demo_account" >/dev/null 2>&1
}

swiftc -O "$here/alfred_window.swift" -o "$helper" || { echo "Couldn't build the window helper (needs Xcode Command Line Tools)" >&2; exit 1; }
trap restore EXIT
tell "set configuration \"vault_path\" to value \"$root/tools/demo/vault\" in workflow \"$bundle\""
tell "remove configuration \"keyfile_path\" in workflow \"$bundle\""
print "add-generic-password -U -s \"$bundle\" -a \"$demo_account\" -w \"$(print -rn -- absolutely-No-clue | base64)\"" | security -i >/dev/null
mkdir -p "$out"

shots=("search|enp " "filter|enp git")
[[ "${1:-}" == fields ]] && shots=()
for shot in $shots; do
  name="${shot%%|*}" query="${shot#*|}"
  tell "search \"$query\""
  sleep 2
  id="$("$helper")" || { echo "Couldn't find the Alfred window" >&2; exit 1; }
  rm -f "$out/$name.png"
  screencapture -x -l "$id" "$out/$name.png" 2>/dev/null
  if [[ ! -s "$out/$name.png" ]]; then
    echo "Screen capture was blocked. Allow Terminal in System Settings → Privacy & Security → Screen & System Audio Recording, then run this again." >&2
    exit 1
  fi
  echo "✓ images/$name.png"
done
# The fields view needs ⇧↩ in Alfred: wait until the workflow starts listing fields, then capture
rm -f "$out/fields.png"
tell 'search "enp github"'
echo
echo ">>> In Alfred, with the first “GitHub” row selected, press ⇧↩ (Shift+Return) <<<"
echo "    (waiting up to 2 minutes; if Alfred closed, it reopens every 20 s)"
for i in {1..600}; do
  if pgrep -f "enpass.js fields" >/dev/null; then
    sleep 1.5
    id="$("$helper")" && screencapture -x -l "$id" "$out/fields.png" 2>/dev/null && echo "✓ images/fields.png"
    break
  fi
  (( i % 100 == 0 )) && tell 'search "enp github"'
  sleep 0.2
done
[[ -s "$out/fields.png" ]] || echo "Fields list wasn't opened; run: tools/demo/shoot.sh fields"
echo "Done. Press Esc to close Alfred."
