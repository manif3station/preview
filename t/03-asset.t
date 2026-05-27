use strict;
use warnings;

use Test::More;

use lib 'lib';

use Preview::Asset;

my $source = Preview::Asset::source_text();
my $sha    = Preview::Asset::source_sha256();
my $page   = Preview::Asset::parse_bookmark();

like( $sha, qr/\A[a-f0-9]{64}\z/, 'dashboards/index has a stable SHA-256 digest' );
like( $source, qr/file => 'browse'/, 'bookmark source includes the browse ajax worker' );
like( $source, qr/file => 'preview'/, 'bookmark source includes the preview ajax worker' );
is( $page->{title}, 'Preview Files', 'bookmark parser extracts the title' );
is( $page->{bookmark}, 'preview', 'bookmark parser extracts the bookmark name' );
is_deeply(
    [ map { $_->{file} } @{ $page->{ajax_blocks} } ],
    [ 'browse', 'preview' ],
    'bookmark parser extracts both ajax worker names',
);
like( $page->{html}, qr/id="preview-list"/, 'bookmark HTML keeps the file list container' );
like( Preview::Asset::static_html(), qr{<title>Preview Files</title>}, 'static_html wraps the bookmark HTML into a standalone page' );

done_testing;
