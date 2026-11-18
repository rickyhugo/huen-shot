# huen-shot

A minimal screenshot CLI for macOS. Drag a rectangle, and huen-shot copies the screenshot to the clipboard as a PNG.

huen-shot has no GUI of its own. It runs the `screencapture` tool that ships with macOS for the selection, then puts the image on the clipboard.

## Install

Build with Zig 0.17, then copy the binary to a directory on your `PATH`.

```sh
zig build -Doptimize=ReleaseSmall
cp zig-out/bin/huen-shot ~/.local/bin/
```

## Take a screenshot

Run `huen-shot`, then drag a rectangle. Press Escape to cancel.

On the first run, macOS asks for the Screen Recording permission. Grant it to the app that starts huen-shot, such as your terminal or your hotkey daemon.

| Exit code | Meaning |
| --- | --- |
| 0 | The screenshot is on the clipboard. |
| 1 | You cancelled the selection, or an error occurred. An error prints a message. |
| 2 | You passed an argument. huen-shot takes none. |

## Keep screenshots on disk

By default, a screenshot exists only on the clipboard. To also keep each screenshot as a file, set `save_dir` in `~/.config/huen-shot/config.toml`.

```toml
save_dir = "~/Pictures/Screenshots"
```

- `save_dir` must be an absolute path or start with `~/`. huen-shot creates the directory if it does not exist.
- The file name is `huen-shot-YYYY-MM-DD-HHMMSS.png` in local time.
- huen-shot prints the path of the saved file to stdout.
- To stop saving, delete the line or put `#` in front of it.

The config parser reads a subset of TOML: comments and the `save_dir` string. Write `save_dir` as a bare key with a string on one line. A double-quoted string cannot contain a backslash. Use single quotes for such a path.

## Develop

```sh
zig build test
```
