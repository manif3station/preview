# TESTING

## Docker Verification

```bash
docker compose -f ~/projects/skills/docker-compose.testing.yml run --rm perl-test bash -lc 'cd /workspace/skills/preview && cpanm --quiet --notest --installdeps . >/tmp/preview-cpanm.log 2>&1 && rm -rf cover_db /workspace/skills/preview/cover_db && HARNESS_PERL_SWITCHES=-MDevel::Cover prove -lr t && cover -report text -select lib/Preview/CLI.pm -select lib/Preview/Directory.pm -select lib/Preview/State.pm -select lib/Preview/Asset.pm'
```

## Verified Result

- Verified on 2026-05-27
- all 8 test files passed
- 80 assertions passed
- selected module statement coverage reached `100.0`
- selected module subroutine coverage reached `100.0`
- `t/04-playwright.t` passed inside the Docker run
- `t/07-installed-ajax-bootstrap.t` proved the installed `~/.developer-dashboard/skills/preview/` Ajax workers load `Preview::*` modules from the skill's own `lib/` path

Coverage summary from the verified run:

```text
lib/Preview/Asset.pm      stmt 100.0
lib/Preview/CLI.pm        stmt 100.0
lib/Preview/Directory.pm  stmt 100.0
lib/Preview/State.pm      stmt 100.0
Total                     stmt 100.0
```

## Cleanup

- remove `cover_db` with a disposable Docker container if host permissions block normal deletion:

```bash
docker run --rm -v ~/projects/skills/skills/preview:/workspace:rw ubuntu bash -lc 'rm -rf /workspace/cover_db'
```
