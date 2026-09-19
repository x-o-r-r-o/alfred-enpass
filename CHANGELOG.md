# Changelog

## 1.0.1 — 2026-09-19

Security and reliability fixes from two independent code audits and live testing.

- Fixed: ⌘, ⌥, ⌃, ⇧ and fn actions did nothing in Alfred (missing modifier connections).
- Only the matching entries are decrypted: copying from an entry whose title has accented or non-Latin
  characters no longer decrypts the whole vault, and usernames, websites and other non-secret fields are
  copied without decrypting anything. An entry that can’t be searched safely is refused instead.
- Notifications no longer name the entry or show website addresses.
- Logins embedded in website addresses (`user:pass@`) are never displayed or Quick Looked.
- Enpass metadata fields (linked Android apps, 2FA hints) are hidden and never used as the default copy.
- A stuck enpass-cli is stopped after 30 seconds instead of leaving Alfred waiting.
- Sturdier handling of unusual vault data (fields without a type, non-text vault IDs).

## 1.0.0 — 2026-09-19

First public release.

- Search the Enpass vault by title, username, category or website (`enp`).
- Copy or paste passwords, usernames, one-time codes and any other field; open websites.
- Copied secrets are hidden from clipboard managers and cleared after a configurable delay.
- Master password saved in the macOS Keychain; keyfile-protected vaults supported.
- Universal Action and Hotkey to start a search.
