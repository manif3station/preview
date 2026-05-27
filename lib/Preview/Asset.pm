package Preview::Asset;

use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use File::Basename qw(dirname);
use File::Spec;

sub skill_root {
    return File::Spec->rel2abs(
        File::Spec->catdir( dirname(__FILE__), File::Spec->updir(), File::Spec->updir() )
    );
}

sub dashboard_path {
    return File::Spec->catfile( skill_root(), 'dashboards', 'index' );
}

sub source_text {
    my $path = dashboard_path();
    open my $fh, '<', $path or die "Unable to read $path: $!";
    local $/;
    my $text = <$fh>;
    close $fh or die "Unable to close $path: $!";
    return $text;
}

sub source_sha256 {
    return sha256_hex( source_text() );
}

sub parse_bookmark {
    my $text = source_text();
    my ($title)    = $text =~ /^TITLE:\s*(.+)$/m;
    my ($bookmark) = $text =~ /^BOOKMARK:\s*(.+)$/m;
    my ($html)     = $text =~ /^HTML:\s*([\s\S]*?)^CODE1:/m;
    my @codes      = $text =~ /^(CODE\d+):\s+Ajax[\s\S]*?file\s*=>\s*'([^']+)'/mg;

    die "Missing title\n" if !defined $title;
    die "Missing bookmark\n" if !defined $bookmark;
    die "Missing HTML block\n" if !defined $html;

    my @ajax_blocks;
    while (@codes) {
        my $label = shift @codes;
        my $file  = shift @codes;
        push @ajax_blocks, { label => $label, file => $file };
    }

    return {
        title       => $title,
        bookmark    => $bookmark,
        html        => $html,
        ajax_blocks => \@ajax_blocks,
    };
}

sub static_html {
    my $page = parse_bookmark();

    return join q{},
      "<!doctype html>\n",
      "<html lang=\"en\">\n",
      "<head>\n<meta charset=\"utf-8\">\n<title>",
      $page->{title},
      "</title>\n</head>\n<body>\n",
      $page->{html},
      "\n</body>\n</html>\n";
}

1;
