package Preview::Directory;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(basename);
use File::Spec;
use MIME::Base64 qw(encode_base64);

sub list_directory {
    my (%args) = @_;
    my $root = normalize_root( $args{root} );
    my ( $path, $relative_path ) = resolve_path(
        root     => $root,
        relative => $args{relative},
    );

    die "Not a directory: $relative_path\n" if !-d $path;

    opendir my $dh, $path or die "Unable to read directory $path: $!";
    my @entries = grep { $_ ne '.' && $_ ne '..' } readdir $dh;
    closedir $dh or die "Unable to close directory $path: $!";

    @entries = sort {
             ( -d File::Spec->catfile( $path, $b ) <=> -d File::Spec->catfile( $path, $a ) )
          || lc($a) cmp lc($b)
          || $a cmp $b
    } @entries;

    return {
        root          => $root,
        current_dir   => $relative_path,
        parent_dir    => _parent_relative($relative_path),
        entries       => [ map { entry_metadata( root => $root, path => File::Spec->catfile( $path, $_ ) ) } @entries ],
        has_selection => @entries ? 1 : 0,
    };
}

sub preview_file {
    my (%args) = @_;
    my $root = normalize_root( $args{root} );
    my ( $path, $relative_path ) = resolve_path(
        root     => $root,
        relative => $args{relative},
    );

    die "Cannot preview a directory: $relative_path\n" if -d $path;

    my $size = -s $path;
    $size = 0 if !defined $size;
    my $mime_type    = mime_type($path);
    my $preview_kind = preview_kind( path => $path, mime_type => $mime_type );
    my $payload      = {
        root          => $root,
        relative_path => $relative_path,
        name          => basename($path),
        size_bytes    => $size,
        mime_type     => $mime_type,
        preview_kind  => $preview_kind,
        too_large     => 0,
    };

    my $max_inline_bytes = $args{max_inline_bytes} || 10 * 1024 * 1024;
    if ( $size > $max_inline_bytes ) {
        $payload->{too_large} = 1;
        $payload->{message}   = "Preview skipped because the file is larger than $max_inline_bytes bytes.";
        return $payload;
    }

    if ( $preview_kind eq 'text' ) {
        $payload->{content} = slurp_raw($path);
        return $payload;
    }

    if ( $preview_kind eq 'binary' ) {
        $payload->{message} = 'Preview is not available for this file type.';
        return $payload;
    }

    $payload->{data_url} = 'data:' . $mime_type . ';base64,' . encode_base64( slurp_raw($path), q{} );
    return $payload;
}

sub entry_metadata {
    my (%args) = @_;
    my $root = normalize_root( $args{root} );
    my $path = $args{path};

    my $absolute = abs_path($path);
    die "Path does not exist: $path\n" if !defined $absolute || !-e $absolute;

    my $name      = basename($absolute);
    my $relative  = _relative_path( $root, $absolute );
    my $directory = -d $absolute ? 1 : 0;
    my $mime_type = $directory ? 'inode/directory' : mime_type($absolute);

    return {
        name          => $name,
        relative_path => $relative,
        path          => $absolute,
        is_directory  => $directory,
        size_bytes    => $directory ? 0 : ( -s $absolute || 0 ),
        mime_type     => $mime_type,
        preview_kind  => $directory ? 'directory' : preview_kind( path => $absolute, mime_type => $mime_type ),
    };
}

sub normalize_root {
    my ($root) = @_;
    die "Directory is required\n" if !defined $root || $root eq q{};
    my $absolute = abs_path($root);
    die "Directory does not exist: $root\n" if !defined $absolute || !-d $absolute;
    return $absolute;
}

sub resolve_path {
    my (%args) = @_;
    my $root     = normalize_root( $args{root} );
    my $relative = defined $args{relative} ? $args{relative} : q{};
    $relative =~ tr{\\}{/};
    $relative =~ s{\A/+}{};

    my @parts = grep { defined $_ && $_ ne q{} } split m{/+}, $relative;
    my $path  = @parts ? File::Spec->catfile( $root, @parts ) : $root;

    my $absolute = abs_path($path);
    die "Path does not exist: $relative\n" if !defined $absolute || !-e $absolute;

    my $prefix = $root . q{/};
    die "Path escapes root: $relative\n" if $absolute ne $root && index( $absolute, $prefix ) != 0;

    return ( $absolute, _relative_path( $root, $absolute ) );
}

sub mime_type {
    my ($path) = @_;
    my %map = (
        pdf  => 'application/pdf',
        png  => 'image/png',
        jpg  => 'image/jpeg',
        jpeg => 'image/jpeg',
        gif  => 'image/gif',
        webp => 'image/webp',
        svg  => 'image/svg+xml',
        bmp  => 'image/bmp',
        txt  => 'text/plain',
        md   => 'text/markdown',
        log  => 'text/plain',
        json => 'application/json',
        js   => 'application/javascript',
        ts   => 'application/typescript',
        css  => 'text/css',
        html => 'text/html',
        xml  => 'application/xml',
        yml  => 'application/yaml',
        yaml => 'application/yaml',
        csv  => 'text/csv',
        pm   => 'text/x-perl',
        pl   => 'text/x-perl',
        sh   => 'text/x-shellscript',
        mp3  => 'audio/mpeg',
        wav  => 'audio/wav',
        ogg  => 'audio/ogg',
        m4a  => 'audio/mp4',
        flac => 'audio/flac',
        mp4  => 'video/mp4',
        mov  => 'video/quicktime',
        webm => 'video/webm',
        m4v  => 'video/x-m4v',
    );

    my ($extension) = lc($path) =~ /\.([^.]+)\z/;
    return $map{$extension} if defined $extension && exists $map{$extension};
    return 'application/octet-stream';
}

sub preview_kind {
    my (%args) = @_;
    my $mime_type = lc( $args{mime_type} || q{} );

    return 'image' if $mime_type =~ m{\Aimage/};
    return 'pdf'   if $mime_type eq 'application/pdf';
    return 'audio' if $mime_type =~ m{\Aaudio/};
    return 'video' if $mime_type =~ m{\Avideo/};
    return 'text'  if $mime_type =~ m{\Atext/};
    return 'text'  if $mime_type =~ m{\Aapplication/(?:json|xml|yaml|javascript|typescript)};
    return _looks_textual( $args{path} ) ? 'text' : 'binary';
}

sub slurp_raw {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Unable to read $path: $!";
    local $/;
    my $raw = <$fh>;
    close $fh or die "Unable to close $path: $!";
    return $raw;
}

sub _looks_textual {
    my ($path) = @_;
    my $raw = slurp_raw($path);
    my $sample = substr( $raw, 0, 1024 );
    return $sample !~ /[\x00-\x08\x0B\x0C\x0E-\x1F]/;
}

sub _relative_path {
    my ( $root, $path ) = @_;
    return q{} if $path eq $root;
    my $prefix = $root . q{/};
    ( my $relative = $path ) =~ s{\A\Q$prefix\E}{};
    return $relative;
}

sub _parent_relative {
    my ($relative) = @_;
    return q{} if !defined $relative || $relative eq q{};
    my @parts = split m{/+}, $relative;
    pop @parts;
    return join q{/}, @parts;
}

1;
