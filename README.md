# Pixel Kitty Desktop Pet

A cute pixel-style macOS desktop pet for TRAE CLI / Codex. It floats on your desktop, follows Codex activity, blinks while idle, waves when you hover on the character, types while work is running, and raises `done` / `help` signs for completion or assistance states.

![Pixel Kitty preview](./optional-trae-custom-pet/contact-sheet.png)

## Download

Download the desktop app package:

[PixelKitty-macOS.zip](./dist/PixelKitty-macOS.zip)

Unzip it, then right-click `PixelKitty.app` and choose **Open**. macOS may ask for confirmation because this is a locally signed app.

## Install From Source Checkout

If you cloned this repository, run:

```sh
./install.sh
```

The script copies `PixelKitty.app` into:

```text
~/Applications/PixelKitty.app
```

and opens it.

## What It Does

- `idle`: Kitty blinks while Codex is not working.
- hover while idle: Kitty waves only when your pointer is actually over the character.
- `working`: Kitty types while Codex is running.
- `done`: Kitty raises a green `done` sign after a task completes.
- `help`: Kitty raises a yellow `help` sign when Codex needs input or permission.

The app reads local TRAE/Codex session logs from `~/.trae/cli/sessions` to infer the current state. It does not need a server.

## Files

- `dist/PixelKitty.app` - the standalone desktop app.
- `dist/PixelKitty-macOS.zip` - downloadable macOS app package.
- `standalone/PixelKittyApp.swift` - macOS app source.
- `standalone/hellokitty-pixel-pet.html` - animated pet UI loaded by the app.
- `optional-trae-custom-pet/` - optional TRAE custom pet resource package.
- `source/` - Swift scripts used to regenerate the optional TRAE sprite sheet.

## Optional TRAE Custom Pet

The folder `optional-trae-custom-pet/` contains the separate TRAE custom pet package:

```text
pet.json
spritesheet.png
contact-sheet.png
```

To install that version manually, copy those files to:

```text
~/.trae/cli/pets/pixel-kitty
```

This optional version is different from the standalone desktop app. The desktop app in `dist/` is the main release.

## Notes

This is an unofficial fan-made pet package. It is not affiliated with or endorsed by any character owner, TRAE, or OpenAI.
