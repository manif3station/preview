use strict;
use warnings FATAL => 'all';

use File::Spec;
use File::Temp qw(tempdir tempfile);
use Test::More;

use lib 'lib';

use Preview::Asset;

my $node_bin     = _find_command('node');
my $chromium_bin = _find_command(qw(chromium chromium-browser google-chrome google-chrome-stable));

plan skip_all => 'Playwright smoke test requires node and Chromium on PATH'
  if !$node_bin || !$chromium_bin || !$ENV{NODE_PATH};

my $tmp = tempdir( CLEANUP => 1, TMPDIR => 1 );
my $html_path = File::Spec->catfile( $tmp, 'preview.html' );
open my $html_fh, '>', $html_path or die "Unable to write $html_path: $!";
print {$html_fh} Preview::Asset::static_html();
close $html_fh or die "Unable to close $html_path: $!";

my ( $script_fh, $script_path ) = tempfile( 'preview-playwright-XXXXXX', SUFFIX => '.js', TMPDIR => 1 );
print {$script_fh} <<'JS';
const { chromium } = require('playwright-core');

async function main() {
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_BIN,
    headless: true
  });
  const page = await browser.newPage();
  await page.route('**/*', (route) => {
    if (route.request().resourceType() === 'xhr') {
      route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ root: '/tmp/demo', current_dir: '', parent_dir: '', entries: [], has_selection: false })
      });
      return;
    }
    route.continue();
  });
  await page.goto(process.env.PREVIEW_URL, { waitUntil: 'domcontentloaded' });
  const title = await page.title();
  const rootText = await page.locator('#preview-root-label').innerText();
  const hasList = await page.locator('#preview-list').count();
  const hasPane = await page.locator('#preview-preview-box').count();
  const hasRootButton = await page.locator('#preview-root-button').count();
  console.log(JSON.stringify({ title, rootText, hasList, hasPane, hasRootButton }));
  await browser.close();
}

main().catch((error) => {
  console.error(String(error && error.stack || error));
  process.exit(1);
});
JS
close $script_fh or die "Unable to close $script_path: $!";

my $cmd = join q{ },
  'NODE_PATH="' . $ENV{NODE_PATH} . '"',
  'CHROMIUM_BIN="' . $chromium_bin . '"',
  'PREVIEW_URL="file://' . $html_path . '"',
  $node_bin,
  $script_path;
my $output = qx{$cmd 2>&1};
my $exit = $? >> 8;
is( $exit, 0, "Playwright smoke flow exits cleanly\n$output" );
my $payload = _json_decode($output);

is( $payload->{title}, 'Preview Files', 'Playwright sees the Preview Files title' );
like( $payload->{rootText}, qr/(?:Current root:|Loading current directory)/, 'Playwright sees the root status area' );
is( $payload->{hasList}, 1, 'Playwright sees the file list container' );
is( $payload->{hasPane}, 1, 'Playwright sees the preview pane container' );
is( $payload->{hasRootButton}, 1, 'Playwright sees the root button' );

done_testing;

sub _find_command {
    for my $name (@_) {
        for my $dir ( split /:/, $ENV{PATH} || q{} ) {
            my $path = File::Spec->catfile( $dir, $name );
            return $path if -x $path;
        }
    }
    return;
}

sub _json_decode {
    my ($text) = @_;
    require JSON::PP;
    return JSON::PP::decode_json($text);
}
