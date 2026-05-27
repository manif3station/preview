# Usage

## Bind The Current Directory

```bash
cd /tmp/abc
dashboard preview.files
```

That stores `/tmp/abc` as the current DD preview root.

## Bind A Specific Directory

```bash
dashboard preview.files ~/Desktop
```

Use this when the directory you want is not the current shell working directory.

## Open The Browser Page

```text
http://127.0.0.1:7890/app/preview
```

After a normal skill install, the page loads its preview modules from `~/.developer-dashboard/skills/preview/lib/` automatically. No extra Perl library export is required.

The page shows:

- a root status banner
- a root button
- an up button
- breadcrumbs
- a file list
- a preview pane

## Proven Preview Cases

- `notes.txt` renders in a `<pre>` block
- `photo.png` renders as an image
- `report.pdf` renders inside an iframe
- `sound.mp3` renders in an audio player
- `movie.mp4` renders in a video player

If a file is too large for inline preview, the preview pane explains that the file was skipped because of the size cap instead of failing silently.
