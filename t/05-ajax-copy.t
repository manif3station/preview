use strict;
use warnings;

use File::Spec;
use FindBin qw($Bin);
use Test::More;

my $skill_root = File::Spec->catdir( $Bin, '..' );
my $source     = File::Spec->catfile( $skill_root, 'dashboards', 'index' );

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "Unable to read $path: $!";
    local $/;
    return <$fh>;
}

sub extract_ajax {
    my ( $content, $file ) = @_;
    if ( $content =~ /CODE\d+:\s+Ajax\b.*?file\s*=>\s*\Q'$file'\E\s*,\s*code\s*=>\s*q\{\n(.*?)(?=\n\};\n(?::--------------------------------------------------------------------------------:|CODE\d+:|__DATA__|\z))/s ) {
        return $1;
    }
    die "Did not find ajax block for $file";
}

sub normalize_body {
    my ($text) = @_;
    $text =~ s/\n+\z//;
    return $text;
}

my $content = slurp($source);
for my $file (qw(browse preview)) {
    my $expected = normalize_body( extract_ajax( $content, $file ) );
    my $actual   = normalize_body( slurp( File::Spec->catfile( $skill_root, 'dashboards', 'ajax', $file ) ) );
    is( $actual, $expected, "$file matches the bookmark ajax worker body" );
}

done_testing;
