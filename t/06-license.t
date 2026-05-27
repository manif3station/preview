use strict;
use warnings;

use File::Spec;
use FindBin qw($Bin);
use Test::More;

my $license = File::Spec->catfile( $Bin, '..', 'LICENSE' );

ok( -f $license, 'LICENSE exists' );
open my $fh, '<', $license or die "Unable to read $license: $!";
local $/;
my $text = <$fh>;
close $fh or die "Unable to close $license: $!";

like( $text, qr/^MIT License/m, 'LICENSE names MIT License' );
like( $text, qr/Permission is hereby granted, free of charge/m, 'LICENSE includes the MIT permission grant' );

done_testing;
