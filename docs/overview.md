# Overview

`preview` is a DD-native local file browser skill.

The workflow is intentionally simple:

1. A shell command chooses the root directory through `dashboard preview.files [directory]`.
2. The skill persists that root under `~/.developer-dashboard/configs/preview/current-root.json`.
3. The `/app/preview` bookmark loads the stored root through the skill Ajax worker.
4. The page lists the current directory and previews supported files inline.

The Ajax workers resolve `Preview::*` modules from the installed skill's own `lib/` directory, so the shipped `/app/preview` route works from a normal `~/.../.developer-dashboard/skills/preview/` install without manual `PERL5LIB` setup.

Supported inline preview classes:

- text
- images
- pdf
- audio
- video

Unsupported binary files still appear in the file list so the operator can see that they exist, but the preview pane shows a clear message instead of dumping raw bytes.

The browser page is intentionally root-scoped. It can move through subdirectories of the selected root, but it does not treat parent directories outside that root as browseable.
