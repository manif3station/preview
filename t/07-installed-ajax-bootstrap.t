use strict;
use warnings;

use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Spec;
use FindBin qw($Bin);
use JSON::PP qw(decode_json encode_json);
use Test::More;
use File::Temp qw(tempdir);

my $skill_root   = File::Spec->catdir( $Bin, '..' );
my $tmp          = tempdir( CLEANUP => 1 );
my $install_root = File::Spec->catdir( $tmp, '.developer-dashboard', 'skills', 'preview' );
my $lib_root     = File::Spec->catdir( $install_root, 'lib', 'Preview' );
my $ajax_root    = File::Spec->catdir( $install_root, 'dashboards', 'ajax' );
my $sample_root  = File::Spec->catdir( $tmp, 'sample-root' );
my $config_root  = File::Spec->catdir( $tmp, 'preview-config' );
my $runner       = File::Spec->catfile( $tmp, 'run-worker.pl' );

make_path( $lib_root, $ajax_root, $sample_root, $config_root );

for my $module (qw(Asset CLI Directory State)) {
    copy(
        File::Spec->catfile( $skill_root, 'lib', 'Preview', "$module.pm" ),
        File::Spec->catfile( $lib_root, "$module.pm" ),
    ) or die "Unable to copy module $module: $!";
}

for my $worker (qw(browse preview)) {
    copy(
        File::Spec->catfile( $skill_root, 'dashboards', 'ajax', $worker ),
        File::Spec->catfile( $ajax_root, $worker ),
    ) or die "Unable to copy worker $worker: $!";
}

open my $sample_fh, '>', File::Spec->catfile( $sample_root, 'notes.txt' )
  or die "Unable to write sample file: $!";
print {$sample_fh} "hello from installed preview\n";
close $sample_fh or die "Unable to close sample file: $!";

open my $state_fh, '>', File::Spec->catfile( $config_root, 'current-root.json' )
  or die "Unable to write preview state: $!";
print {$state_fh} encode_json( { root => $sample_root, updated_at => time } );
close $state_fh or die "Unable to close preview state: $!";

open my $runner_fh, '>', $runner or die "Unable to write runner: $!";
print {$runner_fh} <<'PERL';
use strict;
use warnings;

use JSON::PP qw(encode_json);

my ( $worker, $path ) = @ARGV;

sub params {
    return { path => defined $path ? $path : q{} };
}

my $output = q{};
{
    open my $stdout, '>', \$output or die "Unable to capture stdout: $!";
    local *STDOUT = $stdout;
    my $ok = do $worker;
    die $@ if $@;
    die "Unable to load $worker: $!" if !defined $ok;
}

print encode_json(
    {
        output => $output,
        inc    => {
            directory => $INC{'Preview/Directory.pm'},
            state     => $INC{'Preview/State.pm'},
        },
    }
);
PERL
close $runner_fh or die "Unable to close runner: $!";

sub run_worker {
    my (%args) = @_;

    local $ENV{DEVELOPER_DASHBOARD_AJAX_FILE} = $args{ajax_file};
    local $ENV{PREVIEW_CONFIG_ROOT}           = $config_root;
    local $ENV{HOME}                          = File::Spec->catdir( $tmp, 'home' );
    local $ENV{PERL5LIB}                      = q{};
    local $ENV{PERL5OPT}                      = q{};

    my $command = join q{ },
      map { quotemeta($_) }
      ( $^X, $runner, $args{ajax_file}, ( defined $args{path} ? $args{path} : q{} ) );

    my $raw = qx{$command};
    my $exit = $? >> 8;

    return ( $exit, $raw );
}

subtest 'browse worker loads preview modules from installed lib' => sub {
    my $ajax_file = File::Spec->catfile( $ajax_root, 'browse' );
    my ( $exit, $raw ) = run_worker( ajax_file => $ajax_file, path => q{} );

    is( $exit, 0, 'browse worker exited cleanly' ) or diag $raw;

    my $payload = decode_json($raw);
    is(
        $payload->{inc}->{directory},
        File::Spec->catfile( $install_root, 'lib', 'Preview', 'Directory.pm' ),
        'browse worker loaded Preview::Directory from installed skill lib'
    );
    is(
        $payload->{inc}->{state},
        File::Spec->catfile( $install_root, 'lib', 'Preview', 'State.pm' ),
        'browse worker loaded Preview::State from installed skill lib'
    );

    my $result = decode_json( $payload->{output} );
    is( $result->{root}, $sample_root, 'browse worker returned the configured root' );
    is( scalar @{ $result->{entries} }, 1, 'browse worker listed the sample file' );
};

subtest 'preview worker loads preview modules from installed lib' => sub {
    my $ajax_file = File::Spec->catfile( $ajax_root, 'preview' );
    my ( $exit, $raw ) = run_worker( ajax_file => $ajax_file, path => 'notes.txt' );

    is( $exit, 0, 'preview worker exited cleanly' ) or diag $raw;

    my $payload = decode_json($raw);
    is(
        $payload->{inc}->{directory},
        File::Spec->catfile( $install_root, 'lib', 'Preview', 'Directory.pm' ),
        'preview worker loaded Preview::Directory from installed skill lib'
    );
    is(
        $payload->{inc}->{state},
        File::Spec->catfile( $install_root, 'lib', 'Preview', 'State.pm' ),
        'preview worker loaded Preview::State from installed skill lib'
    );

    my $result = decode_json( $payload->{output} );
    is( $result->{preview_kind}, 'text', 'preview worker returned the sample text preview' );
    like( $result->{content}, qr/installed preview/, 'preview worker returned the sample file content' );
};

done_testing;
