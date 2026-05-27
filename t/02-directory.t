use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use MIME::Base64 qw(encode_base64);
use Test::More;

use lib 'lib';

use Preview::Directory ();

sub write_file {
    my ( $path, $content ) = @_;
    open my $fh, '>:raw', $path or die "Unable to write $path: $!";
    print {$fh} $content;
    close $fh or die "Unable to close $path: $!";
}

my $tmp = tempdir( CLEANUP => 1 );
my $root = File::Spec->catdir( $tmp, 'root' );
my $nested = File::Spec->catdir( $root, 'docs' );
mkdir $root or die "Unable to mkdir $root: $!";
mkdir $nested or die "Unable to mkdir $nested: $!";

write_file( File::Spec->catfile( $root, 'notes.txt' ), "hello\nworld\n" );
write_file( File::Spec->catfile( $root, 'photo.png' ), "\x89PNG\x0d\x0a\x1a\x0aPNGDATA" );
write_file( File::Spec->catfile( $root, 'sound.mp3' ), "ID3sound" );
write_file( File::Spec->catfile( $root, 'movie.mp4' ), "....ftypisomvideo" );
write_file( File::Spec->catfile( $root, 'report.pdf' ), "%PDF-1.7\npdf\n" );
write_file( File::Spec->catfile( $root, 'script' ), "#!/bin/sh\necho hi\n" );
write_file( File::Spec->catfile( $root, 'blob.bin' ), "\x00\x01\x02" );
write_file( File::Spec->catfile( $nested, 'deep.txt' ), "deep\n" );

is( Preview::Directory::normalize_root($root), $root, 'normalize_root returns the absolute root path' );
is( Preview::Directory::mime_type('demo.json'), 'application/json', 'mime_type maps JSON files' );
is( Preview::Directory::mime_type('demo.unknown'), 'application/octet-stream', 'mime_type falls back for unknown extensions' );
is( Preview::Directory::preview_kind( path => File::Spec->catfile( $root, 'photo.png' ), mime_type => 'image/png' ), 'image', 'preview_kind detects image media' );
is( Preview::Directory::preview_kind( path => File::Spec->catfile( $root, 'sound.mp3' ), mime_type => 'audio/mpeg' ), 'audio', 'preview_kind detects audio media' );
is( Preview::Directory::preview_kind( path => File::Spec->catfile( $root, 'movie.mp4' ), mime_type => 'video/mp4' ), 'video', 'preview_kind detects video media' );
is( Preview::Directory::preview_kind( path => File::Spec->catfile( $root, 'report.pdf' ), mime_type => 'application/pdf' ), 'pdf', 'preview_kind detects pdf media' );
is( Preview::Directory::preview_kind( path => File::Spec->catfile( $root, 'script' ), mime_type => 'application/octet-stream' ), 'text', 'preview_kind promotes textual extensionless files' );
is( Preview::Directory::preview_kind( path => File::Spec->catfile( $root, 'blob.bin' ), mime_type => 'application/octet-stream' ), 'binary', 'preview_kind keeps opaque binaries as binary' );

my ( $docs_path, $docs_relative ) = Preview::Directory::resolve_path( root => $root, relative => 'docs' );
is( $docs_path, $nested, 'resolve_path returns the nested absolute path' );
is( $docs_relative, 'docs', 'resolve_path returns the nested relative path' );

my $listing = Preview::Directory::list_directory( root => $root );
is( $listing->{root}, $root, 'list_directory reports the active root' );
is( $listing->{current_dir}, q{}, 'list_directory root current_dir is empty' );
is( $listing->{parent_dir}, q{}, 'list_directory root has no parent_dir' );
ok( $listing->{has_selection}, 'list_directory reports entries exist' );
is( $listing->{entries}[0]{name}, 'docs', 'list_directory sorts directories before files' );
is( $listing->{entries}[0]{preview_kind}, 'directory', 'directory entries are marked as directory preview kind' );

my $nested_listing = Preview::Directory::list_directory( root => $root, relative => 'docs' );
is( $nested_listing->{current_dir}, 'docs', 'nested list_directory reports the relative directory' );
is( $nested_listing->{parent_dir}, q{}, 'nested list_directory reports the parent relative path' );
is( $nested_listing->{entries}[0]{name}, 'deep.txt', 'nested list_directory lists the child file' );

my $text_preview = Preview::Directory::preview_file( root => $root, relative => 'notes.txt' );
is( $text_preview->{preview_kind}, 'text', 'preview_file detects text previews' );
is( $text_preview->{content}, "hello\nworld\n", 'preview_file returns the text content' );

my $image_preview = Preview::Directory::preview_file( root => $root, relative => 'photo.png' );
like( $image_preview->{data_url}, qr{\Adata:image/png;base64,}, 'preview_file returns an image data URL' );
is( $image_preview->{data_url}, 'data:image/png;base64,' . encode_base64( "\x89PNG\x0d\x0a\x1a\x0aPNGDATA", q{} ), 'image preview uses the raw file bytes' );

my $audio_preview = Preview::Directory::preview_file( root => $root, relative => 'sound.mp3' );
like( $audio_preview->{data_url}, qr{\Adata:audio/mpeg;base64,}, 'preview_file returns an audio data URL' );

my $video_preview = Preview::Directory::preview_file( root => $root, relative => 'movie.mp4' );
like( $video_preview->{data_url}, qr{\Adata:video/mp4;base64,}, 'preview_file returns a video data URL' );

my $pdf_preview = Preview::Directory::preview_file( root => $root, relative => 'report.pdf' );
like( $pdf_preview->{data_url}, qr{\Adata:application/pdf;base64,}, 'preview_file returns a pdf data URL' );

my $binary_preview = Preview::Directory::preview_file( root => $root, relative => 'blob.bin' );
is( $binary_preview->{preview_kind}, 'binary', 'preview_file keeps unknown binaries as binary' );
like( $binary_preview->{message}, qr/Preview is not available/, 'binary previews return a helpful message' );

my $too_large_preview = Preview::Directory::preview_file(
    root             => $root,
    relative         => 'notes.txt',
    max_inline_bytes => 2,
);
ok( $too_large_preview->{too_large}, 'preview_file reports files that exceed the inline size limit' );
like( $too_large_preview->{message}, qr/larger than 2 bytes/, 'preview_file explains the inline size cap' );

my $metadata = Preview::Directory::entry_metadata(
    root => $root,
    path => File::Spec->catfile( $root, 'notes.txt' ),
);
is( $metadata->{relative_path}, 'notes.txt', 'entry_metadata reports relative file paths' );
is( $metadata->{mime_type}, 'text/plain', 'entry_metadata reports the file mime type' );

{
    my $error = eval { Preview::Directory::resolve_path( root => $root, relative => '../outside' ); 1 };
    ok( !$error, 'resolve_path rejects paths outside the root' );
    like( $@, qr/^Path does not exist: \.\.\/outside/, 'resolve_path reports missing escaped paths clearly' );
}

{
    my $error = eval { Preview::Directory::list_directory( root => $root, relative => 'notes.txt' ); 1 };
    ok( !$error, 'list_directory rejects file paths' );
    like( $@, qr/^Not a directory: notes\.txt/, 'list_directory reports file-path misuse clearly' );
}

{
    my $error = eval { Preview::Directory::preview_file( root => $root, relative => 'docs' ); 1 };
    ok( !$error, 'preview_file rejects directories' );
    like( $@, qr/^Cannot preview a directory: docs/, 'preview_file reports directory preview misuse clearly' );
}

{
    my $error = eval { Preview::Directory::normalize_root( File::Spec->catdir( $tmp, 'missing' ) ); 1 };
    ok( !$error, 'normalize_root rejects a missing directory' );
    like( $@, qr/^Directory does not exist:/, 'normalize_root explains a missing directory clearly' );
}

done_testing;
