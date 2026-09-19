#!/bin/zsh
# Regenerates the encrypted test vaults in test/fixtures from tools/base-vault
# (the sample vault shipped with enpass-cli, MIT licensed).
# Dev only. Needs: enpass-cli, sqlcipher (brew install enpass-cli sqlcipher), python3.
#
#   test/fixtures/vault          password "absolutely-No-clue", no keyfile, many edge cases
#   test/fixtures/vault-keyfile  same password + test/fixtures/test.enpasskey
#   test/fixtures/vault-empty    no entries
set -euo pipefail
cd "${0:A:h}/.."

export MASTERPW="absolutely-No-clue"
SQLCIPHER="${SQLCIPHER:-$(brew --prefix sqlcipher)/bin/sqlcipher}"
FIX=test/fixtures
rm -rf "$FIX/vault" "$FIX/vault-keyfile" "$FIX/vault-empty"
mkdir -p "$FIX/vault"
cp tools/base-vault/vault.enpassdb tools/base-vault/vault.json "$FIX/vault/"

# Raw SQLCipher key: PBKDF2-HMAC-SHA512(password [+ keyfile bytes], first 16 bytes of the db, kdf_iter)
dbkey() { # vault_dir [keyfile]
  python3 - "$1" "${2:-}" <<'PY'
import hashlib, json, re, sys
vault, keyfile = sys.argv[1], sys.argv[2]
pw = b"absolutely-No-clue"
if keyfile:
    pw += bytes.fromhex(re.search(r">([0-9a-fA-F]+)<", open(keyfile).read()).group(1))
salt = open(vault + "/vault.enpassdb", "rb").read(16)
iters = json.load(open(vault + "/vault.json"))["kdf_iter"]
print(hashlib.pbkdf2_hmac("sha512", pw, salt, iters)[:32].hex())
PY
}

sql() { # vault_dir [keyfile] < statements
  local key; key="$(dbkey "$@")"
  { print "PRAGMA key=\"x'$key'\";"; print "PRAGMA cipher_compatibility=3;"; cat; } |
    "$SQLCIPHER" "$1/vault.enpassdb" | { grep -v '^ok$' || true; }
}

cli() { enpass-cli -vault "$FIX/vault" -nonInteractive -force -log error "$@"; }

# Entries created through enpass-cli (it encrypts the password field)
cli -title "GitHub" -login "alice@example.com" -password 'gh-P@ss w0rd!' -url "https://github.com/login" -category login create
cli -title "GitHub" -login "bob@work.example" -password "second-github" -url "github.com" -category login create
cli -title "Bank of Ümlaut 🏦" -login "jürgen" -password "ünïcødé-🔑-pässwörd" -url "https://bank.example.de/login" -category finance create
cli -title 'Quote "Test" \ back $HOME `x`' -login "o'neil" -password 'a"b\c$d`e'"'"'f;g|h&i' -category login create
cli -title "Only Password" -password "only-pass" -category login create
cli -title "Secure Note" -notes "Just a note" -category note create
cli -title "Trashed Entry" -login "trash@example.com" -password "trash-pw" -category login create
cli -title "Wi-Fi Home" -password "wifi pass with  two spaces " -category wifi create
cli -title "Leading-Space Password" -login "space@example.com" -password " padded " -category login create
cli -title "A very long title that goes on and on to check that Alfred truncates it gracefully without breaking anything at all" -login "long@example.com" -password "long-pw" -url "https://long.example.com" create
cli trash "Trashed Entry"

# Extra fields enpass-cli can't create
sql "$FIX/vault" <<'SQL'
-- TOTP (RFC 6238 test secret) + second website + custom sensitive field + section on GitHub (alice)
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'','JBSWY3DPEHPK3PXP',0,1,0,'totp',10 FROM item WHERE title='GitHub' AND subtitle='alice@example.com';
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Recovery','',0,0,0,'section',11 FROM item WHERE title='GitHub' AND subtitle='alice@example.com';
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Recovery PIN','8472',0,1,0,'pin',12 FROM item WHERE title='GitHub' AND subtitle='alice@example.com';
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Docs','https://docs.github.com',0,0,0,'url',13 FROM item WHERE title='GitHub' AND subtitle='alice@example.com';
-- Enpass metadata fields are hidden from the fields list
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'','com.github.android',0,0,0,'.Android#',15 FROM item WHERE title='GitHub' AND subtitle='alice@example.com';
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'','1',0,0,0,'.twoFA',16 FROM item WHERE title='GitHub' AND subtitle='alice@example.com';
-- A deleted field must never show up
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Old field','must-not-appear',1,0,0,'text',14 FROM item WHERE title='GitHub' AND subtitle='alice@example.com';
-- Invalid TOTP secret on the second GitHub entry
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'','not base32!!',0,1,0,'totp',10 FROM item WHERE title='GitHub' AND subtitle='bob@work.example';
-- Credit card with sensitive non-password fields
INSERT INTO item (uuid,created_at,field_updated_at,title,subtitle,note,trashed,deleted,category,icon,last_used)
  VALUES ('0c0ffee0-0000-4000-8000-00000000cafe',1,1,'Visa Card','•••• 4242','',0,0,'creditcard','card_cc',1);
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde) VALUES
  ('0c0ffee0-0000-4000-8000-00000000cafe','Cardholder','Jane Doe',0,0,0,'ccName',1),
  ('0c0ffee0-0000-4000-8000-00000000cafe','Number','4242424242424242',0,1,0,'ccNumber',2),
  ('0c0ffee0-0000-4000-8000-00000000cafe','CVC','123',0,1,0,'ccCvc',3),
  ('0c0ffee0-0000-4000-8000-00000000cafe','Expiry','12/30',0,0,0,'ccExpiry',4);
-- Deleted item must never show up
INSERT INTO item (uuid,created_at,field_updated_at,title,subtitle,note,trashed,deleted,category,icon,last_used)
  VALUES ('dead0000-0000-4000-8000-000000000000',1,1,'Deleted Item','gone','',0,1,'login','card_password',1);
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  VALUES ('dead0000-0000-4000-8000-000000000000','','gone',0,0,0,'username',1);
-- Enpass Wi-Fi items keep the password in a field labelled "Password" of type password; website without scheme
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Network name','HomeNet',0,0,0,'text',0 FROM item WHERE title='Wi-Fi Home';
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Router','192.168.1.1',0,0,0,'url',5 FROM item WHERE title='Wi-Fi Home';
-- Secret field types without the sensitive flag, and websites with schemes that must never be opened
INSERT INTO item (uuid,created_at,field_updated_at,title,subtitle,note,trashed,deleted,category,icon,last_used)
  VALUES ('f1a90000-0000-4000-8000-00000000f1a9',1,1,'Unflagged Secrets','','',0,0,'misc','card_password',1);
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde) VALUES
  ('f1a90000-0000-4000-8000-00000000f1a9','','JBSWY3DPEHPK3PXP',0,0,0,'totp',1),
  ('f1a90000-0000-4000-8000-00000000f1a9','Door PIN','9999',0,0,0,'pin',2),
  ('f1a90000-0000-4000-8000-00000000f1a9','','file:///System/Applications/Calculator.app',0,0,0,'url',3),
  ('f1a90000-0000-4000-8000-00000000f1a9','NAS','smb://nas/share',0,0,0,'url',4),
  ('f1a90000-0000-4000-8000-00000000f1a9','Router','router.local:8080/admin',0,0,0,'url',5);
SQL

# Keyfile vault: same content, re-keyed with password + keyfile
mkdir -p "$FIX/vault-keyfile"
cp "$FIX/vault/vault.enpassdb" "$FIX/vault/vault.json" "$FIX/vault-keyfile/"
cat > "$FIX/test.enpasskey" <<'KEY'
<?xml version="1.0" encoding="UTF-8"?>
<enpass_key_file>6f1c2d3e4a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f</enpass_key_file>
KEY
newkey="$(dbkey "$FIX/vault-keyfile" "$FIX/test.enpasskey")"
print "PRAGMA rekey=\"x'$newkey'\";" | sql "$FIX/vault-keyfile"
python3 - "$FIX/vault-keyfile/vault.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["have_keyfile"] = 1; d["vault_name"] = "KeyfileVault"
d["vault_uuid"] = "11111111-2222-4333-8444-555555555555"
json.dump(d, open(p, "w"), indent=4)
PY

# Empty vault
mkdir -p "$FIX/vault-empty"
cp tools/base-vault/vault.enpassdb tools/base-vault/vault.json "$FIX/vault-empty/"
print "UPDATE item SET deleted=1;" | sql "$FIX/vault-empty"
python3 - "$FIX/vault-empty/vault.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["vault_name"] = "EmptyVault"
d["vault_uuid"] = "00000000-0000-4000-8000-000000000000"
json.dump(d, open(p, "w"), indent=4)
PY

enpass-cli -vault "$FIX/vault" -nonInteractive -log error dryrun
enpass-cli -vault "$FIX/vault-keyfile" -keyfile "$FIX/test.enpasskey" -nonInteractive -log error dryrun
enpass-cli -vault "$FIX/vault-empty" -nonInteractive -log error dryrun
print "Fixtures written to $FIX"
