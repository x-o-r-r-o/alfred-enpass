## Usage

Search your [Enpass](https://www.enpass.io) vault via the `enp` keyword. Type to filter by title, username, category or website.

* <kbd>↩</kbd> Copy password (or paste it, as set in the Workflow’s Configuration).
* <kbd>fn</kbd><kbd>↩</kbd> Do the opposite: paste instead of copy, or copy instead of paste.
* <kbd>⌘</kbd><kbd>↩</kbd> Copy username.
* <kbd>⌥</kbd><kbd>↩</kbd> Copy one-time code.
* <kbd>⌃</kbd><kbd>↩</kbd> Open website.
* <kbd>⇧</kbd><kbd>↩</kbd> Show all fields of the entry.
* <kbd>⌘</kbd><kbd>Y</kbd> Quick Look website.

In the fields list, <kbd>↩</kbd> copies a field, <kbd>⌘</kbd><kbd>↩</kbd> pastes it and <kbd>⌃</kbd><kbd>↩</kbd> opens a website field. Type `lock` to forget the saved master password.

Turn on Touch ID in the Workflow’s Configuration to lock the vault after a period of inactivity; `enp` then asks for Touch ID (or your Mac password on Macs without it) before showing entries. Type `lock` to lock it right away.

Copied values are hidden from clipboard managers, including Alfred’s Clipboard History, and the clipboard is cleared after 30 seconds unless you copied something else in the meantime.

Alternatively, search Enpass for selected text or a website’s domain via the Universal Action.

Configure the Hotkey to open the search directly.

## Setup

The first search asks for your Enpass master password. It is checked against the vault and saved in your macOS Keychain. If your vault uses a keyfile, choose it in the Workflow’s Configuration.

The vault is read with [enpass-cli](https://github.com/hazcod/enpass-cli) and never modified. This workflow isn’t affiliated with Enpass and was built with the help of an AI assistant (Claude).
