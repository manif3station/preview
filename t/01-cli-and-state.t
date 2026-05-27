use strict;
use warnings;

use Cwd qw(getcwd);
use File::Spec;
use File::Temp qw(tempdir);
use JSON::PP qw(decode_json);
use Test::More;

use lib 'lib';

use Preview::CLI ();
use Preview::State ();

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $root = File::Spec->catdir( $tmp, 'root' );
    mkdir $root or die "Unable to mkdir $root: $!";

    local $ENV{PREVIEW_CONFIG_ROOT} = File::Spec->catdir( $tmp, 'config' );

    my $stdout = q{};
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    local *STDOUT = $out;

    my $exit = Preview::CLI::main( argv => [$root] );
    is( $exit, 0, 'cli exits cleanly for an explicit directory' );

    my $payload = decode_json($stdout);
    is( $payload->{ok}, 1, 'cli marks the result as ok' );
    is( $payload->{root}, $root, 'cli reports the stored absolute root' );
    is( $payload->{bookmark}, 'preview', 'cli reports the DD bookmark name' );
    like( $payload->{url}, qr{/app/preview\z}, 'cli reports the DD bookmark URL' );
    is( Preview::State::load_root(), $root, 'state load returns the saved root' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    local $ENV{PREVIEW_CONFIG_ROOT} = File::Spec->catdir( $tmp, 'config' );

    my $cwd = getcwd();
    my $exit = Preview::CLI::main( argv => [] );
    is( $exit, 0, 'cli exits cleanly when no directory is passed' );
    is( Preview::State::load_root(), $cwd, 'cli defaults to the current working directory' );
}

{
    my $stderr = q{};
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDERR = $err;
    my $exit = Preview::CLI::main( argv => [ '/tmp', '/var' ] );
    is( $exit, 1, 'cli rejects extra positional arguments' );
    like( $stderr, qr/^Usage: dashboard preview\.files \[directory\]/, 'cli prints the usage line' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    local $ENV{PREVIEW_CONFIG_ROOT} = File::Spec->catdir( $tmp, 'config' );
    my $error = eval { Preview::State::store_root( root => File::Spec->catdir( $tmp, 'missing' ) ); 1 };
    ok( !$error, 'store_root dies for a missing directory' );
    like( $@, qr/^Directory does not exist:/, 'store_root reports the missing directory clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    local $ENV{PREVIEW_CONFIG_ROOT} = File::Spec->catdir( $tmp, 'config' );
    local $ENV{PWD} = $tmp;
    is( Preview::State::load_root(), $tmp, 'load_root falls back to PWD when no saved state exists' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    local $ENV{PREVIEW_CONFIG_ROOT};
    local $ENV{HOME} = $tmp;
    is(
        Preview::State::config_root(),
        File::Spec->catdir( $tmp, '.developer-dashboard', 'configs', 'preview' ),
        'config_root falls back to the HOME-based DD preview path',
    );
}

done_testing;
