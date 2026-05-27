package Preview::State;

use strict;
use warnings;

use Cwd qw(abs_path getcwd);
use File::Path qw(make_path);
use File::Spec;
use JSON::PP qw(decode_json encode_json);

sub config_root {
    return $ENV{PREVIEW_CONFIG_ROOT} if defined $ENV{PREVIEW_CONFIG_ROOT} && $ENV{PREVIEW_CONFIG_ROOT} ne q{};

    my $home = $ENV{HOME} || die "HOME is required\n";
    return File::Spec->catdir( $home, '.developer-dashboard', 'configs', 'preview' );
}

sub state_file {
    return File::Spec->catfile( config_root(), 'current-root.json' );
}

sub store_root {
    my (%args) = @_;
    my $root = _absolute_directory( $args{root} );
    my $dir  = config_root();

    make_path($dir) if !-d $dir;

    my $payload = {
        root       => $root,
        updated_at => time,
    };

    open my $fh, '>', state_file() or die "Unable to write " . state_file() . ": $!";
    print {$fh} encode_json($payload);
    close $fh or die "Unable to close " . state_file() . ": $!";

    return $payload;
}

sub load_root {
    if ( -f state_file() ) {
        open my $fh, '<', state_file() or die "Unable to read " . state_file() . ": $!";
        local $/;
        my $raw = <$fh>;
        close $fh or die "Unable to close " . state_file() . ": $!";
        my $payload = decode_json($raw);
        return _absolute_directory( $payload->{root} );
    }

    my $cwd = defined $ENV{PWD} && $ENV{PWD} ne q{} ? $ENV{PWD} : getcwd();
    return _absolute_directory($cwd);
}

sub _absolute_directory {
    my ($path) = @_;

    die "Directory is required\n" if !defined $path || $path eq q{};

    my $absolute = abs_path($path);
    die "Directory does not exist: $path\n" if !defined $absolute || !-d $absolute;

    return $absolute;
}

1;
