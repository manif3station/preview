# 2026-05-27 - Installed Ajax Bootstrap Fix

The `preview` DD page now resolves its own Perl modules correctly from the installed skill tree.

- fixed the Ajax worker bootstrap to search upward from the installed worker file until it finds `lib/Preview/Directory.pm`
- kept the saved Ajax worker files and the embedded bookmark Ajax blocks aligned
- added a Docker-backed regression test that simulates the installed `~/.developer-dashboard/skills/preview/` layout and executes both Ajax workers directly
