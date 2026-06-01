# preview

`preview` is a Developer Dashboard skill that turns the current local directory into a browser file navigator with inline previews for common file types.

It solves the gap between shell work and quick visual inspection. When you are already working inside a folder, you often want the DD web UI to show that exact directory without building a separate app or manually wiring a server route. This skill binds the chosen local folder into Developer Dashboard and gives the user a ready file-browser page with preview support.

The skill adds:

- `dashboard preview.files [directory]`
- the `/app/preview` browser page
- bookmark-backed Ajax workers for directory browsing and file preview

What it does:

- stores the requested directory, or the current working directory when no argument is passed
- exposes that directory as the current root for the DD browser page
- lists files and subdirectories from that root and allows moving deeper into child folders
- previews text, images, pdf, audio, and video files inline
- keeps unknown binary files visible in the list while reporting that they are not previewable inline
- loads the skill's own Perl modules from the installed skill path so `/app/preview` works after a normal `dashboard skills install`

## Installation

Install the skill into Developer Dashboard by repo name:

```bash
dashboard skills install preview
```

## CLI Usage

Bind the current shell directory:

```bash
cd /tmp/abc
dashboard preview.files
```

Bind an explicit directory instead:

```bash
dashboard preview.files ~/Documents/reports
```

The command prints JSON that includes the stored root and the browser URL:

```json
{"ok":1,"root":"/tmp/abc","bookmark":"preview","url":"http://127.0.0.1:7890/app/preview"}
```

## Browser Usage

1. Run `dashboard preview.files` from the directory you want to inspect.
2. Open `http://127.0.0.1:7890/app/preview`.
3. Click folders to browse deeper.
4. Click files to preview them inline.

Normal-case example:

```bash
cd /tmp/abc
dashboard preview.files
```

Then open `http://127.0.0.1:7890/app/preview` and preview `notes.txt`, `report.pdf`, `photo.png`, `demo.mp3`, or `clip.mp4`.

Edge-case examples:

```bash
dashboard preview.files ~/Downloads
```

This uses a directory outside the current shell location.

```bash
dashboard preview.files
```

If the selected folder contains a large file, the page keeps the file visible but tells the user when the inline preview was skipped because the file exceeded the configured size cap.

## Documentation

- [Overview](docs/overview.md)
- [Usage](docs/usage.md)

## License

MIT. See [LICENSE](LICENSE).
