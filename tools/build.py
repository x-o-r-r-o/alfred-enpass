#!/usr/bin/env python3
"""Generate workflow/info.plist and package dist/Enpass.alfredworkflow.

Usage: python3 tools/build.py [--install]
  --install  also copy the build into the installed workflow in Alfred's preferences,
             keeping its configuration (prefs.plist), instead of re-importing
"""
import json
import pathlib
import plistlib
import shutil
import sys
import uuid
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / "workflow"
DIST = ROOT / "dist"
VERSION = "1.0.0"
BUNDLE_ID = "com.x-o-r-r-o.alfred.enpass"
PACKAGE = "Enpass.alfredworkflow"
# Only these files are shipped; anything else in workflow/ (e.g. prefs.plist) stays local
SHIPPED = ["enpass.js", "icon.png", "info.plist", "icons"]


def uid(name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"enpass-alfred/{name}")).upper()


objects, connections, uidata = [], {}, {}


def add(name, type_, version, config, x, y, note=None):
    objects.append({"uid": uid(name), "type": type_, "version": version, "config": config})
    uidata[uid(name)] = {"xpos": x, "ypos": y, **({"note": note} if note else {})}


# Alfred only runs a modifier action (⌘↩ etc.) through a connection made for that modifier
MODIFIERS = {"cmd": 1048576, "alt": 524288, "ctrl": 262144, "shift": 131072, "fn": 8388608}


def connect(src, dst, condition=None, modifiers=0):
    link = {"destinationuid": uid(dst), "modifiers": modifiers, "modifiersubtext": "", "vitoclose": False}
    if condition:
        link["sourceoutputuid"] = uid(condition)
    connections.setdefault(uid(src), []).append(link)


def script_filter(name, keyword, mode, title, subtext, running, x, y, note=None):
    config = {
        "alfredfiltersresults": True,
        "alfredfiltersresultsmatchmode": 0,
        "argumenttreatemptyqueryasnil": False,
        "argumenttrimmode": 0,
        "argumenttype": 1,
        "escaping": 102,
        "queuedelaycustom": 3,
        "queuedelayimmediatelyinitially": True,
        "queuedelaymode": 0,
        "queuemode": 1,
        "runningsubtext": running,
        "script": f'./enpass.js {mode} "${{1}}"',
        "scriptargtype": 1,
        "scriptfile": "",
        "skipuniversalaction": True,
        "subtext": subtext,
        "title": title,
        "type": 11,
        "withspace": True,
    }
    if keyword:
        config["keyword"] = keyword
    add(name, "alfred.workflow.input.scriptfilter", 3, config, x, y, note)


# ── Inputs ──────────────────────────────────────────────────────────────────
script_filter("sf_list", "{var:keyword}", "list", "Search Enpass",
              "Copy passwords, usernames and one-time codes", "Unlocking vault…", 30, 60)
add("hotkey", "alfred.workflow.trigger.hotkey", 2, {
    "action": 0, "argument": 0, "focusedappvariable": False, "focusedappvariablename": "",
    "hotkey": 0, "hotmod": 0, "leftcursor": False, "modsmode": 0, "relatedAppsMode": 0,
}, 30, 230, "Set a hotkey to search Enpass")
add("ua_search", "alfred.workflow.trigger.universalaction", 1, {
    "acceptsfiles": False, "acceptsmulti": 0, "acceptstext": True, "acceptsurls": True,
    "name": "Search Enpass",
}, 30, 380)

# ── Routing ─────────────────────────────────────────────────────────────────
add("route", "alfred.workflow.utility.conditional", 1, {
    "conditions": [{
        "inputstring": "{var:action}", "matchcasesensitive": True, "matchmode": 0,
        "matchstring": "fields", "outputlabel": "Show fields", "uid": uid("cond_fields"),
    }],
    "elselabel": "Run action", "hideelse": False,
}, 260, 60)
add("to_fields", "alfred.workflow.utility.argument", 1, {
    "argument": "", "passthroughargument": False, "variables": {},
}, 430, 20)
script_filter("sf_fields", None, "fields", "Entry fields",
              "Copy any field of the entry", "Loading fields…", 560, 20,
              "Fields of the entry chosen with ⇧↩")
add("set_search", "alfred.workflow.utility.argument", 1, {
    "argument": "{query}", "passthroughargument": True, "variables": {"action": "search"},
}, 260, 380)

# ── Actions ─────────────────────────────────────────────────────────────────
add("run_act", "alfred.workflow.action.script", 2, {
    "concurrently": False, "escaping": 102, "script": './enpass.js act "${1}"',
    "scriptargtype": 1, "scriptfile": "", "type": 11,
}, 760, 200, "Copies or pastes the chosen value, opens websites, stores the master password")
add("notify", "alfred.workflow.output.notification", 1, {
    "lastpathcomponent": False, "onlyshowifquerypopulated": True, "removeextension": False,
    "text": "{query}", "title": "{var:notif_title}",
}, 960, 200)

for mods in [0, *MODIFIERS.values()]:
    connect("sf_list", "route", modifiers=mods)
    connect("sf_fields", "run_act", modifiers=mods)
connect("hotkey", "sf_list")
connect("route", "to_fields", "cond_fields")
connect("route", "run_act")
connect("to_fields", "sf_fields")
connect("ua_search", "set_search")
connect("set_search", "run_act")
connect("run_act", "notify")

# ── User configuration ──────────────────────────────────────────────────────
user_config = [
    {"type": "textfield", "variable": "keyword", "label": "Keyword",
     "description": "Keyword to search your vault.",
     "config": {"default": "enp", "placeholder": "enp", "required": True, "trim": True}},
    {"type": "filepicker", "variable": "vault_path", "label": "Vault Folder",
     "description": "In Enpass: Settings → Advanced → Data Location, then the folder of the vault (usually “primary”).",
     "config": {"default": "~/Library/Containers/in.sinew.Enpass-Desktop/Data/Documents/Vaults/primary",
                "filtermode": 1, "placeholder": "", "required": True}},
    {"type": "filepicker", "variable": "keyfile_path", "label": "Keyfile",
     "description": "Only if the vault is protected with a keyfile.",
     "config": {"default": "", "filtermode": 0, "placeholder": "", "required": False}},
    {"type": "popupbutton", "variable": "default_action", "label": "Action",
     "description": "What ↩ does with a password or field. fn↩ does the other.",
     "config": {"default": "copy", "pairs": [["Copy to clipboard", "copy"], ["Paste into frontmost app", "paste"]]}},
    {"type": "popupbutton", "variable": "clear_after", "label": "Clear Clipboard",
     "description": "Only cleared if you haven’t copied something else in the meantime.",
     "config": {"default": "30", "pairs": [["After 10 seconds", "10"], ["After 20 seconds", "20"],
                                           ["After 30 seconds", "30"], ["After 45 seconds", "45"],
                                           ["After 60 seconds", "60"], ["After 90 seconds", "90"],
                                           ["Never", "0"]]}},
    {"type": "checkbox", "variable": "show_trashed", "label": "Trash",
     "description": "",
     "config": {"default": False, "required": False, "text": "Include entries in the Enpass trash"}},
    {"type": "textfield", "variable": "enpass_cli", "label": "enpass-cli Path",
     "description": "Leave empty to find it in /opt/homebrew/bin or /usr/local/bin.",
     "config": {"default": "", "placeholder": "/opt/homebrew/bin/enpass-cli", "required": False, "trim": True}},
]

README = (ROOT / "tools/readme_alfred.md").read_text()

info = {
    "bundleid": BUNDLE_ID,
    "category": "Productivity",
    "connections": connections,
    "createdby": "x-o-r-r-o",
    "description": "Search your Enpass vault and copy passwords, usernames and one-time codes",
    "disabled": False,
    "name": "Enpass",
    "objects": objects,
    "readme": README,
    "uidata": uidata,
    "userconfigurationconfig": user_config,
    "variablesdontexport": [],
    "version": VERSION,
    "webaddress": "https://github.com/x-o-r-r-o/alfred-enpass",
}

with open(WORKFLOW / "info.plist", "wb") as f:
    plistlib.dump(info, f, sort_keys=True)

DIST.mkdir(exist_ok=True)
package = DIST / PACKAGE
files = []
for name in SHIPPED:
    path = WORKFLOW / name
    files += sorted(p for p in path.rglob("*") if p.is_file()) if path.is_dir() else [path]
with zipfile.ZipFile(package, "w", zipfile.ZIP_DEFLATED) as z:
    for path in files:
        if path.name == ".DS_Store":
            continue
        entry = zipfile.ZipInfo.from_file(path, path.relative_to(WORKFLOW).as_posix())
        with open(path, "rb") as src:
            z.writestr(entry, src.read(), zipfile.ZIP_DEFLATED)

print(f"Built {package.relative_to(ROOT)} (v{VERSION}, {len(objects)} objects, {len(files)} files)")

if "--install" in sys.argv:
    prefs = pathlib.Path.home() / "Library/Application Support/Alfred/prefs.json"
    workflows = pathlib.Path(json.loads(prefs.read_text()).get("current", "")) / "workflows"
    targets = [
        d for d in workflows.iterdir()
        if (d / "info.plist").exists()
        and plistlib.loads((d / "info.plist").read_bytes()).get("bundleid") == BUNDLE_ID
    ]
    if not targets:
        sys.exit(f"Not installed yet: open dist/{PACKAGE} to import it first")
    for target in targets:
        for path in target.iterdir():
            if path.name != "prefs.plist":
                shutil.rmtree(path) if path.is_dir() else path.unlink()
        for name in SHIPPED:
            path = WORKFLOW / name
            dest = target / name
            shutil.copytree(path, dest) if path.is_dir() else shutil.copy2(path, dest)
        print(f"Installed into {target}")
