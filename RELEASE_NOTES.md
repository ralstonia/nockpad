# Nockpad 0.1.0 — Public Preview

Gather your thoughts. Take aim.

Nockpad brings a Pomodoro timer, a Kanban board, and an independent jotpad into one
native Mac workspace with a dark terminal-inspired interface.

- Quiet focus ticking, ambient noise when focus stops, and optional window activation.
- Drag-and-drop task board with task notes and pomodoro estimates.
- Searchable standalone notes with automatic local saving and plain-text copying.
- Menu-bar timer controls and keyboard shortcuts for switching workspaces.
- Local storage with visible errors rather than a silent temporary task database.

## Download

Requires **macOS 14 or later**. The ZIP includes both **Apple Silicon and Intel**
architectures. Unzip and move `Nockpad.app` to Applications.

This preview is **ad-hoc signed and not Apple-notarized**. macOS may block the first
launch. Read [Apple's guidance](https://support.apple.com/102445) before choosing
whether to allow the app. You can also build from source with Xcode.

Verify the download by placing the ZIP and `SHA256SUMS.txt` in the same directory:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

## Scope and limitations

- Built for both architectures; interactive use has been exercised on Apple Silicon.
  Intel and all supported macOS versions have not been independently tested.
- No cloud synchronization, automatic updater, rich-text notes, or built-in backup.
- Source is public for inspection; an open-source license has not yet been granted.
- A possible disappearance was reported during personal use; there was no matching
  crash report and its cause remains unresolved.
- This is a separate app identity from the personal FocusBoard version. No personal
  tasks, notes, settings, private repository history, or data migration are included.

Validation: universal Release build, code-signature verification after ZIP extraction,
archive integrity and SHA-256 checks, timer/audio transition checks, and note
save/reload, Unicode, corrupt-file preservation, and write-failure checks.
