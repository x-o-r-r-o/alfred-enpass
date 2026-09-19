#!/bin/zsh
# Builds tools/demo/vault: realistic-looking entries for README screenshots (password "absolutely-No-clue").
# Dev only. Needs: enpass-cli, sqlcipher, python3.
set -euo pipefail
cd "${0:A:h}/../.."
export MASTERPW="absolutely-No-clue"
SQLCIPHER="${SQLCIPHER:-$(brew --prefix sqlcipher)/bin/sqlcipher}"
V=tools/demo/vault
rm -rf "$V"; mkdir -p "$V"
cp tools/base-vault/vault.enpassdb tools/base-vault/vault.json "$V/"
python3 - "$V/vault.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["vault_name"] = "Personal"; d["vault_uuid"] = "de300000-0000-4000-8000-00000000de30"
json.dump(d, open(p, "w"), indent=4)
PY
key="$(python3 -c "
import hashlib,json
salt=open('$V/vault.enpassdb','rb').read(16); it=json.load(open('$V/vault.json'))['kdf_iter']
print(hashlib.pbkdf2_hmac('sha512',b'absolutely-No-clue',salt,it)[:32].hex())")"
sql() { { print "PRAGMA key=\"x'$key'\";"; print "PRAGMA cipher_compatibility=3;"; cat; } | "$SQLCIPHER" "$V/vault.enpassdb" | { grep -v '^ok$' || true; }; }
cli() { enpass-cli -vault "$V" -nonInteractive -force -log error "$@"; }

print "UPDATE item SET deleted=1;" | sql
cli -title "GitHub" -login "jane.appleseed@example.com" -password "demo-Gh-2026!" -url "https://github.com/login" -category login create
cli -title "GitHub (work)" -login "jane@acme.example" -password "demo-work-gh" -url "https://github.com/login" -category login create
cli -title "Netflix" -login "jane.appleseed@example.com" -password "demo-netflix" -url "https://www.netflix.com/login" -category login create
cli -title "Amazon" -login "jane.appleseed@example.com" -password "demo-amazon" -url "https://www.amazon.com" -category login create
cli -title "Google" -login "jane.appleseed@gmail.example" -password "demo-google" -url "https://accounts.google.com" -category login create
cli -title "Dropbox" -login "jane.appleseed@example.com" -password "demo-dropbox" -url "https://www.dropbox.com/login" -category login create
cli -title "Home Wi-Fi" -password "demo-wifi-pass" -category wifi create
sql <<'SQL'
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'','JBSWY3DPEHPK3PXP',0,1,0,'totp',10 FROM item WHERE title IN ('GitHub','Google','Dropbox') AND deleted=0;
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Recovery codes','',0,0,0,'section',11 FROM item WHERE title='GitHub' AND deleted=0;
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Recovery code','demo-7f3a-91c2',0,1,0,'text',12 FROM item WHERE title='GitHub' AND deleted=0;
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Docs','https://docs.github.com',0,0,0,'url',13 FROM item WHERE title='GitHub' AND deleted=0;
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde)
  SELECT uuid,'Network name','Appleseed-5G',0,0,0,'text',0 FROM item WHERE title='Home Wi-Fi' AND deleted=0;
INSERT INTO item (uuid,created_at,field_updated_at,title,subtitle,note,trashed,deleted,category,icon,last_used)
  VALUES ('de30cafe-0000-4000-8000-00000000cafe',1,1,'Visa Card','•••• 4242','',0,0,'creditcard','card_cc',1);
INSERT INTO itemfield (item_uuid,label,value,deleted,sensitive,historical,type,orde) VALUES
  ('de30cafe-0000-4000-8000-00000000cafe','Cardholder','Jane Appleseed',0,0,0,'ccName',1),
  ('de30cafe-0000-4000-8000-00000000cafe','Number','4242424242424242',0,1,0,'ccNumber',2),
  ('de30cafe-0000-4000-8000-00000000cafe','CVC','123',0,1,0,'ccCvc',3),
  ('de30cafe-0000-4000-8000-00000000cafe','Expiry','12/30',0,0,0,'ccExpiry',4);
SQL
enpass-cli -vault "$V" -nonInteractive -log error dryrun
print "Demo vault written to $V"
