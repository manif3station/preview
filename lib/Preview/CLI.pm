package Preview::CLI;

use strict;
use warnings;

use Cwd qw(getcwd);
use JSON::PP qw(encode_json);

use Preview::State ();

sub main {
    my (%args) = @_;
    my $argv = $args{argv} || [];

    if ( @{$argv} > 1 ) {
        print STDERR "Usage: dashboard preview.files [directory]\n";
        return 1;
    }

    my $target = @{$argv} ? $argv->[0] : getcwd();
    my $saved  = Preview::State::store_root( root => $target );

    print encode_json(
        {
            ok       => 1,
            root     => $saved->{root},
            bookmark => 'preview',
            url      => 'http://127.0.0.1:7890/app/preview',
        }
    );
    print "\n";

    return 0;
}

1;
