#!/bin/zsh
# End-to-end tests: runs workflow/enpass.js against the encrypted fixture vaults in test/fixtures.
# Usage: test/run.sh
# Needs enpass-cli. Uses a separate Keychain item (removed at the end) and saves/restores the
# clipboard text. Dry-run mode stops the script from pasting, opening URLs or scripting Alfred.
emulate -L zsh
TESTS="${0:A:h}"
FIX="$TESTS/fixtures"
cd "$TESTS/../workflow" || exit 1
PW="absolutely-No-clue"
TMP="$(mktemp -d)"
SERVICE="com.x-o-r-r-o.alfred.enpass.test.$$"

export enpass_dry_run=1
export enpass_keychain_service="$SERVICE"
export alfred_workflow_bundleid="com.x-o-r-r-o.alfred.enpass"
export vault_path="$FIX/vault"
export keyfile_path=""
export clear_after=0
unset enpass_cli show_trashed default_action keyword action entry_uuid entry_title field_index field_type mode

export LANG="${LANG:-en_US.UTF-8}"
saved_clipboard="$(pbpaste 2>/dev/null)"
cleanup() {
  # One item per test vault account: delete until none are left
  while security delete-generic-password -s "$SERVICE" >/dev/null 2>&1; do :; done
  while security delete-generic-password -s "$SERVICE-canary" >/dev/null 2>&1; do :; done
  print -rn -- "$saved_clipboard" | pbcopy
  rm -rf "$TMP"
}
trap cleanup EXIT

fail=0 count=0
check() { # name, output, python assertion over d (parsed JSON)
  local name="$1" out="$2" expr="$3"
  count=$((count + 1))
  if print -r -- "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); assert $expr, d" 2>"$TMP/err"; then
    print "✓ $name"
  else
    print "✗ $name"; print -r -- "$out" | head -c 800; print; tail -3 "$TMP/err"; fail=1
  fi
}
check_sh() { # name, shell condition
  count=$((count + 1))
  if eval "$2"; then print "✓ $1"; else print "✗ $1"; fail=1; fi
}
list() { ./enpass.js list "$1" 2>&1; }
fields() { entry_uuid="$1" entry_title="$2" ./enpass.js fields "" 2>&1; }
act() { ./enpass.js act "${1:-}" 2>&1; }
store_pw() { # password for the fixture vault account (base64, as the workflow stores it)
  local account="$1" b64; b64="$(print -rn -- "$2" | base64)"
  print "add-generic-password -U -s \"$SERVICE\" -a \"$account\" -w \"$b64\"" | security -i >/dev/null
}
uuid_of() { # title [username] → uuid from the current list output
  print -r -- "$LIST" | python3 -c "
import json,sys; d=json.load(sys.stdin)
print(next(i['arg'] for i in d['items'] if i['title']==sys.argv[1] and (len(sys.argv)<3 or sys.argv[2] in i['subtitle'])))" "$@"
}
clip() { osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSPasteboard.generalPasteboard.stringForType($.NSPasteboardTypeString).js || ""'; }
clip_types() { osascript -l JavaScript -e 'ObjC.import("AppKit"); ObjC.deepUnwrap($.NSPasteboard.generalPasteboard.types).join(",")'; }
totp_now() { python3 -c "
import base64,hmac,struct,time,hashlib
k=base64.b32decode('JBSWY3DPEHPK3PXP'); c=struct.pack('>Q',int(time.time())//30)
h=hmac.new(k,c,hashlib.sha1).digest(); o=h[-1]&15
print('%06d'%((struct.unpack('>I',h[o:o+4])[0]&0x7fffffff)%1000000))"; }
VAULT_ACCOUNT="24b18ce1-6e6a-40d7-a584-123ae9e2996c"
SECRETS=('gh-P@ss w0rd!' 'second-github' 'ünïcødé' 'only-pass' 'trash-pw' 'noIdeaata11' '4242424242424242' '8472' 'JBSWY3DPEHPK3PXP' '9999' "$PW")
no_secrets() { # output contains none of the fixture secrets
  local s; for s in "${SECRETS[@]}"; do [[ "$1" == *"$s"* ]] && { print "  leaked: $s"; return 1; }; done; return 0
}

print "── Setup errors"
check "cli missing (custom path)" "$(enpass_cli=/nope/enpass-cli list '')" "d['items'][0]['title']=='enpass-cli not found at the configured path' and d['items'][0]['variables']['action']=='configure'"
check "cli missing (not installed)" "$(enpass_test_candidates=/nope/a:/nope/b list '')" "d['items'][0]['title']=='Install enpass-cli to use this workflow' and d['items'][0]['variables']=={'action':'copy_text','text':'brew install enpass-cli'}"
check "vault folder missing" "$(vault_path=/nope/vault list '')" "d['items'][0]['title']=='Enpass vault folder not found' and d['skipknowledge']"
check "not a vault folder" "$(vault_path=$FIX list '')" "d['items'][0]['title']=='Not an Enpass vault folder'"
check "vault path is a file" "$(vault_path=$FIX/test.enpasskey list '')" "d['items'][0]['title']=='Enpass vault folder not found'"
check "keyfile required" "$(vault_path=$FIX/vault-keyfile list '')" "d['items'][0]['title']=='This vault needs a keyfile'"
check "keyfile missing" "$(vault_path=$FIX/vault-keyfile keyfile_path=/nope/key list '')" "d['items'][0]['title']=='Keyfile not found'"
check "tilde vault path" "$(vault_path='~/nope-enpass-vault' list '')" "d['items'][0]['subtitle'].startswith('$HOME/nope-enpass-vault')"
check "no saved password" "$(list '')" "d['items'][0]['title']=='Unlock DummyVault vault' and d['items'][0]['variables']['action']=='setpassword' and [i['title'] for i in d['items'][1:]]==['Open Enpass','Workflow Configuration']"

print "── Master password"
check "wrong password rejected" "$(enpass_test_answer=wrong action=setpassword act)" "d['alfredworkflow']['variables']['notif_title']=='Vault not unlocked'"
check_sh "nothing stored after wrong password" "! security find-generic-password -s $SERVICE >/dev/null 2>&1"
check "empty password rejected" "$(enpass_test_answer= action=setpassword act)" "d['alfredworkflow']['variables']['notif_title']=='Vault not unlocked'"
check "correct password saved" "$(enpass_test_answer=$PW action=setpassword act)" "d['alfredworkflow']['variables']['notif_title']=='Vault unlocked'"
check_sh "stored base64 in Keychain" "[[ \$(security find-generic-password -s $SERVICE -a $VAULT_ACCOUNT -w) == \$(print -rn -- $PW | base64) ]]"
check "forget" "$(action=forget act)" "d['alfredworkflow']['variables']['notif_title']=='Master password forgotten'"
check "forget again" "$(action=forget act)" "d['alfredworkflow']['variables']['notif_title']=='Nothing to forget'"
store_pw "$VAULT_ACCOUNT" "wrong-password"
check "wrong stored password" "$(list '')" "d['items'][0]['title']=='Wrong master password or keyfile' and d['items'][0]['variables']['action']=='setpassword' and d['items'][1]['title']=='Forget Master Password'"
check "action with wrong stored password asks again" "$(enpass_test_answer=$PW action=field entry_uuid=x field_index=0 field_type=password act)" "d['alfredworkflow']['variables']['notif_title']=='Vault unlocked'"
# Round-trip of a non-ASCII master password through savePassword/getPassword (keyfile vault account)
KF_ACCOUNT="11111111-2222-4333-8444-555555555555"
store_pw "$KF_ACCOUNT" 'pä"ss \ wörd 🔑 $x'
check_sh "non-ASCII password stored readable" "[[ \$(security find-generic-password -s $SERVICE -a $KF_ACCOUNT -w | base64 -D) == 'pä\"ss \\ wörd 🔑 \$x' ]]"
check "keyfile vault: wrong password" "$(vault_path=$FIX/vault-keyfile keyfile_path=$FIX/test.enpasskey list '')" "d['items'][0]['title']=='Wrong master password or keyfile'"

# A vault name with a newline must not inject a second `security -i` command
EVIL="$TMP/evil-vault"; mkdir -p "$EVIL"; cp "$FIX/vault/vault.enpassdb" "$EVIL/"
python3 -c "
import json,sys; d=json.load(open(sys.argv[1])); d['vault_name']='Evil\\ndelete-generic-password -s $SERVICE-canary'; d['vault_uuid']='evil-account'
json.dump(d,open(sys.argv[2],'w'))" "$FIX/vault/vault.json" "$EVIL/vault.json"
print "add-generic-password -s \"$SERVICE-canary\" -a canary -w canary" | security -i >/dev/null
check "vault name with newline" "$(vault_path=$EVIL enpass_test_answer=$PW action=setpassword act)" "d['alfredworkflow']['variables']['notif_title']=='Vault unlocked'"
check_sh "no command injected via vault name" "security find-generic-password -s $SERVICE-canary -a canary >/dev/null 2>&1"
security delete-generic-password -s "$SERVICE-canary" >/dev/null 2>&1

print "── Listing"
LIST="$(list '')"
check "lists entries sorted, no trashed/deleted" "$LIST" "[i['title'] for i in d['items'] if 'uid' in i]==['A very long title that goes on and on to check that Alfred truncates it gracefully without breaking anything at all','ÄÖÜ','Bank of Ümlaut 🏦','GitHub','GitHub','Leading-Space Password','Only Password','Quote \"Test\" \\\\ back \$HOME \`x\`','Unflagged Secrets','Visa Card','Whatever','Wi-Fi Home','日本銀行']"
check "utility rows" "$LIST" "[i['title'] for i in d['items'][-3:]]==['Forget Master Password','Open Enpass','Workflow Configuration']"
check "cached, not skipknowledge" "$LIST" "d['cache']=={'seconds':60,'loosereload':True} and 'skipknowledge' not in d"
check_sh "list output has no secrets" "no_secrets \"\$LIST\""
check "duplicate titles have distinct uids" "$LIST" "len({i['uid'] for i in d['items'] if i['title']=='GitHub'})==2"
check "GitHub row" "$LIST" "(lambda i: i['subtitle']=='alice@example.com · Login' and i['variables']['action']=='field' and i['variables']['field_type']=='password' and i['variables']['mode']=='copy' and i['mods']['alt']['valid'] and i['mods']['ctrl']['arg']=='https://github.com/login' and i['quicklookurl']=='https://github.com/login' and 'github.com' in i['match'] and 'docs.github.com' in i['match'] and i['text']['copy']=='alice@example.com')(next(i for i in d['items'] if i['subtitle'].startswith('alice')))"
check "URL without scheme gets https" "$LIST" "next(i for i in d['items'] if i['subtitle'].startswith('bob'))['mods']['ctrl']['arg']=='https://github.com'"
check "only password: no username/url/totp" "$LIST" "(lambda i: not i['mods']['cmd']['valid'] and not i['mods']['alt']['valid'] and not i['mods']['ctrl']['valid'] and i['subtitle']=='Login')(next(i for i in d['items'] if i['title']=='Only Password'))"
check "card: primary is number, subtitle from Enpass" "$LIST" "(lambda i: i['variables']['field_type']=='ccNumber' and i['subtitle']=='•••• 4242 · Credit Card' and i['icon']['path']=='icons/creditcard.png')(next(i for i in d['items'] if i['title']=='Visa Card'))"
check "category icons" "$LIST" "next(i for i in d['items'] if i['title']=='Wi-Fi Home')['icon']['path']=='icons/wifi.png' and next(i for i in d['items'] if i['title']=='Bank of Ümlaut 🏦')['icon']['path']=='icons/finance.png'"
check "fn does the other mode" "$LIST" "all(i['mods']['fn']['variables']['mode']=='paste' for i in d['items'] if 'uid' in i)"
check "paste mode" "$(default_action=paste list '')" "all(i['variables'].get('mode')=='paste' and i['mods']['fn']['variables']['mode']=='copy' and i['mods']['cmd'].get('subtitle','').startswith(('Paste','No')) for i in d['items'] if 'uid' in i)"
check "show trashed" "$(show_trashed=1 list '')" "(lambda i: i['subtitle'].startswith('In Trash') and i['icon']['path']=='icons/trash.png')(next(i for i in d['items'] if i['title']=='Trashed Entry'))"
store_pw "00000000-0000-4000-8000-000000000000" "$PW"
check "empty vault" "$(vault_path=$FIX/vault-empty list '')" "d['items'][0]['title']=='No entries in EmptyVault' and d['items'][0]['valid']==False"
store_pw "$KF_ACCOUNT" "$PW"
check "keyfile vault lists" "$(vault_path=$FIX/vault-keyfile keyfile_path=$FIX/test.enpasskey list '')" "sum('uid' in i for i in d['items'])==13"
check "keyfile vault, wrong keyfile" "$(vault_path=$FIX/vault-keyfile keyfile_path=$FIX/vault/vault.json list '')" "d['items'][0]['title'] in ('Could not read the keyfile','Keyfile problem','Wrong master password or keyfile')"
check "keyfile set but not needed is ignored" "$(keyfile_path=$FIX/test.enpasskey list '')" "sum('uid' in i for i in d['items'])==13"
check "custom cli path" "$(enpass_cli=$(command -v enpass-cli) list '')" "sum('uid' in i for i in d['items'])==13"

print "── Fields"
GH="$(uuid_of GitHub alice)"; BOB="$(uuid_of GitHub bob)"; CARD="$(uuid_of 'Visa Card')"
QUOTE="$(uuid_of 'Quote "Test" \ back $HOME `x`')"; UML="$(uuid_of 'Bank of Ümlaut 🏦')"
LEAD="$(uuid_of Leading-Space\ Password)"; WIFI="$(uuid_of 'Wi-Fi Home')"; ONLY="$(uuid_of 'Only Password')"
F="$(fields $GH GitHub)"
check "fields of GitHub (alice)" "$F" "[(i['title'],i['subtitle']) for i in d['items']]==[('Password','••••••••'),('Username','alice@example.com'),('Website','https://github.com/login'),('One-time code','Current code'),('Recovery PIN','Recovery › ••••••••'),('Docs','Recovery › https://docs.github.com'),('Back to Search','Return to all entries')]"
check_sh "fields output has no secrets" "no_secrets \"\$F\""
check "field rows carry index, type and label" "$F" "d['items'][3]['variables']=={'entry_uuid':'$GH','entry_title':'GitHub','action':'field','field_index':'3','field_type':'totp','field_label':'One-time code','field_secret':'1','mode':'copy'}"
check "website field opens with ctrl" "$F" "d['items'][5]['mods']['ctrl']['valid'] and d['items'][5]['mods']['ctrl']['variables']['action']=='open_field' and not d['items'][0]['mods']['ctrl']['valid']"
check "fields of duplicate-title entry" "$(fields $BOB GitHub)" "d['items'][1]['subtitle']=='bob@work.example'"
check "fields with sections (Whatever)" "$(fields $(uuid_of Whatever) Whatever)" "any(i['subtitle']=='OUTGOING › smtp.whatever.com' for i in d['items']) and any(i['title']=='Email' for i in d['items'])"
check "fields of card" "$(fields $CARD 'Visa Card')" "[i['title'] for i in d['items']][:4]==['Cardholder','Number','CVC','Expiry'] and d['items'][1]['subtitle']=='••••••••'"
check "fields: unknown entry" "$(fields nope-uuid Nope)" "d['items'][0]['title']=='Entry not found' and d['items'][-1]['title']=='Back to Search'"
check "fields: title renamed, uuid still found" "$(fields $GH 'Old Title')" "d['items'][1]['subtitle']=='alice@example.com'"
check "fields: title with shell characters" "$(fields $QUOTE 'Quote \"Test\" \ back \$HOME \`x\`')" "d['items'][1]['subtitle']==\"o'neil\""

UNF="$(uuid_of 'Unflagged Secrets')"
check "unflagged secret types are masked in the list" "$LIST" "(lambda i: i['variables']['field_type']=='pin' and i['mods']['alt']['valid'] and i['mods']['ctrl']['arg']=='https://router.local:8080/admin' and 'file' not in i['match'] and i.get('quicklookurl')=='https://router.local:8080/admin')(next(i for i in d['items'] if i['title']=='Unflagged Secrets'))"
F2="$(fields $UNF 'Unflagged Secrets')"
check "unflagged secret types are masked in fields" "$F2" "[(i['title'],i['subtitle']) for i in d['items'][:2]]==[('One-time code','Current code'),('Door PIN','••••••••')] and 'text' not in d['items'][0] and 'text' not in d['items'][1]"
check_sh "unflagged fields output has no secrets" "no_secrets \"\$F2\""
check "only web addresses can be opened" "$F2" "[i['mods']['ctrl']['valid'] for i in d['items'][2:5]]==[False,False,True]"

print "── Copying"
field() { entry_uuid="$1" entry_title="$2" action=field field_index="$3" field_type="$4" mode="${5:-copy}" act; }
check "copy password" "$(field $GH GitHub 0 password)" "d['alfredworkflow']['variables']['notif_title']=='Copied password' and d['alfredworkflow']['arg']=='Clipboard won’t be cleared automatically.'"
check_sh "clipboard has password" "[[ \$(clip) == 'gh-P@ss w0rd!' ]]"
check_sh "clipboard marked concealed+transient" "[[ \$(clip_types) == *org.nspasteboard.ConcealedType*org.nspasteboard.TransientType* ]]"
field $BOB GitHub 0 password >/dev/null
check_sh "duplicate title copies the right one" "[[ \$(clip) == 'second-github' ]]"
TRACE="$TMP/cli-calls"; : > "$TRACE"
printf '#!/bin/zsh\nprint -r -- "${(j: :)@}" >> %s\nexec %s "$@"\n' "$TRACE" "$(command -v enpass-cli)" > "$TMP/enpass-cli"
chmod +x "$TMP/enpass-cli"
enpass_cli="$TMP/enpass-cli" field $UML 'Bank of Ümlaut 🏦' 0 password >/dev/null
check_sh "unicode password" "[[ \$(clip) == 'ünïcødé-🔑-pässwörd' ]]"
check_sh "non-ASCII title: show runs with a filter only" "! grep -qE ' show\$' \"\$TRACE\" && grep -q ' show mlaut 🏦' \"\$TRACE\""
enpass_cli="$TMP/enpass-cli" field $GH 'Renamed Title' 0 password >/dev/null
check_sh "renamed entry: found without decrypting the whole vault" "! grep -qE ' show\$' \"\$TRACE\""
: > "$TRACE"
enpass_cli="$TMP/enpass-cli" entry_uuid=$GH entry_title=GitHub action=field field_index=1 field_type=username field_label=Username field_secret=0 act >/dev/null
check_sh "non-secret field copied without decrypting" "! grep -q ' show ' \"\$TRACE\" && [[ \$(clip) == alice@example.com ]]"
: > "$TRACE"
enpass_cli="$TMP/enpass-cli" entry_uuid=$GH entry_title=GitHub action=username act >/dev/null
check_sh "username copied without decrypting" "! grep -q ' show ' \"\$TRACE\""
CJK="$(uuid_of 日本銀行)"; UNS="$(uuid_of ÄÖÜ)"
: > "$TRACE"
enpass_cli="$TMP/enpass-cli" field $CJK 日本銀行 0 password >/dev/null
check_sh "CJK title: filtered copy" "[[ \$(clip) == cjk-pass ]] && ! grep -qE ' show\$' \"\$TRACE\""
: > "$TRACE"
check "unsearchable title is refused, not whole-vault decrypted" "$(enpass_cli=$TMP/enpass-cli field $UNS ÄÖÜ 0 password)" "d['alfredworkflow']['variables']['notif_title']=='Can’t read this entry from Alfred'"
check_sh "…and no unfiltered show ran" "! grep -qE ' show\$' \"\$TRACE\""
printf '#!/bin/zsh\nsleep 20\n' > "$TMP/slow-cli"; chmod +x "$TMP/slow-cli"
started=$SECONDS
check "stuck enpass-cli is stopped" "$(enpass_test_timeout=1 enpass_cli=$TMP/slow-cli list '')" "d['items'][0]['title']=='enpass-cli took too long'"
check_sh "…within the timeout, children included" "(( SECONDS - started < 8 ))"
field $QUOTE 'Quote "Test" \ back $HOME `x`' 0 password >/dev/null
check_sh "shell-hostile password" "[[ \$(clip) == 'a\"b\\c\$d\`e'\"'\"'f;g|h&i' ]]"
field $LEAD 'Leading-Space Password' 0 password >/dev/null
check_sh "leading/trailing spaces kept" "[[ \$(clip) == ' padded ' ]]"
field $WIFI 'Wi-Fi Home' 0 password >/dev/null
check_sh "double and trailing spaces kept" "[[ \$(clip) == 'wifi pass with  two spaces ' ]]"
field $CARD 'Visa Card' 1 ccNumber >/dev/null
check_sh "card number" "[[ \$(clip) == 4242424242424242 ]]"
field $GH GitHub 5 pin >/dev/null
check_sh "custom sensitive field" "[[ \$(clip) == 8472 ]]"
field $GH GitHub 6 url >/dev/null
check_sh "non-sensitive field" "[[ \$(clip) == https://docs.github.com ]]"
check "paste mode notification" "$(field $GH GitHub 0 password paste)" "d['alfredworkflow']['variables']['notif_title']=='Pasted password'"
check "clear timer text" "$(clear_after=30 field $ONLY 'Only Password' 0 password)" "d['alfredworkflow']['arg']=='Clipboard clears in 30 s.' and 'Only' not in json.dumps(d)"
check "username" "$(entry_uuid=$GH entry_title=GitHub action=username act)" "d['alfredworkflow']['variables']['notif_title']=='Copied username' and 'GitHub' not in json.dumps(d)"
check_sh "clipboard has username" "[[ \$(clip) == alice@example.com ]]"
check "username missing (no title in notification)" "$(entry_uuid=$ONLY entry_title='Only Password' action=username act)" "d['alfredworkflow']['variables']['notif_title']=='No username' and 'Only' not in json.dumps(d)"
check "one-time code" "$(field $GH GitHub 3 totp)" "d['alfredworkflow']['variables']['notif_title']=='Copied one-time code'"
check_sh "TOTP matches RFC 6238" "[[ \$(clip) == \$(totp_now) ]]"
check "invalid TOTP secret" "$(field $BOB GitHub 3 totp)" "d['alfredworkflow']['variables']['notif_title']=='Could not generate the one-time code'"
check "field changed since listing" "$(field $GH GitHub 0 username)" "d['alfredworkflow']['variables']['notif_title']=='Entry changed'"
check "field index out of range" "$(field $GH GitHub 99 password)" "d['alfredworkflow']['variables']['notif_title']=='Entry changed'"
check "field label changed since listing" "$(field_label=Other field $GH GitHub 0 password)" "d['alfredworkflow']['variables']['notif_title']=='Entry changed'"
check "open file:// website refused" "$(entry_uuid=$UNF entry_title='Unflagged Secrets' action=open_field field_index=2 act)" "d['alfredworkflow']['variables']['notif_title']=='No website to open'"
check "open smb:// website refused" "$(entry_uuid=$UNF entry_title='Unflagged Secrets' action=open_field field_index=3 act)" "d['alfredworkflow']['variables']['notif_title']=='No website to open'"
check "unflagged TOTP code" "$(field $UNF 'Unflagged Secrets' 0 totp)" "d['alfredworkflow']['variables']['notif_title']=='Copied one-time code'"
check_sh "unflagged TOTP matches" "[[ \$(clip) == \$(totp_now) ]]"
check "unknown entry" "$(field nope Nope 0 password)" "d['alfredworkflow']['variables']['notif_title']=='Entry not found'"
check "open website" "$(entry_uuid=$GH entry_title=GitHub action=url act)" "d['alfredworkflow']['arg']==''"
check "open website field" "$(entry_uuid=$GH entry_title=GitHub action=open_field field_index=6 act)" "d['alfredworkflow']['arg']==''"
check "open website missing" "$(entry_uuid=$ONLY entry_title='Only Password' action=url act)" "d['alfredworkflow']['variables']['notif_title']=='No website to open'"
check "copy install command" "$(action=copy_text text='brew install enpass-cli' act)" "d['alfredworkflow']['arg']=='brew install enpass-cli'"
check_sh "install command copied" "[[ \$(clip) == 'brew install enpass-cli' ]]"
check "search, configure, open, back" "$(for a in search configure open_enpass back; do action=$a act https://www.github.com/x; done | python3 -c 'import json,sys; print(json.dumps([json.loads(l) for l in sys.stdin]))')" "all(x['alfredworkflow']['arg']=='' for x in d)"
check "unknown action" "$(action=bogus act)" "d['alfredworkflow']['variables']['notif_title']=='Unknown action'"
check "unknown mode" "$(./enpass.js bogus)" "d['items'][0]['valid']==False"

print "── Workflow wiring (info.plist)"
PLIST="$(plutil -convert json -o - info.plist)"
check "every modifier has a connection from both Script Filters" "$PLIST" "(lambda t, c: all(sorted(x['modifiers'] for x in c[u])==[0,131072,262144,524288,1048576,8388608] for u,ty in t.items() if ty=='alfred.workflow.input.scriptfilter'))({o['uid']:o['type'] for o in d['objects']}, d['connections'])"
check "config fields" "$PLIST" "[c['variable'] for c in d['userconfigurationconfig']]==['keyword','vault_path','keyfile_path','default_action','clear_after','show_trashed','enpass_cli'] and d['userconfigurationconfig'][0]['config']['default']=='enp'"

print "── Clipboard clearing"
setclip() { osascript -l JavaScript -e 'function run(argv) { ObjC.import("AppKit"); const p = $.NSPasteboard.generalPasteboard; p.clearContents; p.setStringForType($(argv[0]), $.NSPasteboardTypeString) }' "$1" >/dev/null; }
setclip "keep me"
count_now="$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSPasteboard.generalPasteboard.changeCount')"
./enpass.js clear $((count_now - 1))
check_sh "clear skips when clipboard changed" "[[ \$(clip) == 'keep me' ]]"
./enpass.js clear "$count_now"
check_sh "clear empties unchanged clipboard" "[[ -z \$(clip) ]]"
clear_after=1 field $ONLY 'Only Password' 0 password >/dev/null
check_sh "timer: copied" "[[ \$(clip) == only-pass ]]"
sleep 2.5
check_sh "timer: cleared after 1 s" "[[ -z \$(clip) ]]"
clear_after=1 field $ONLY 'Only Password' 0 password >/dev/null
setclip "copied later"
sleep 2.5
check_sh "timer: keeps newer clipboard" "[[ \$(clip) == 'copied later' ]]"

print
if (( fail )); then print "FAILED ($count checks)"; exit 1; fi
print "All $count checks passed"
