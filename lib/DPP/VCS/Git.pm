package DPP::VCS::Git;

use 5.010000;
use strict;
use warnings;
use Carp qw(cluck croak carp);
use Data::Dumper;
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration   use DPP::VCS::Git ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

                                 ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

               );

our $VERSION = '0.01';

#use vars qw( $GIT_DIR );


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);
    $self->{GIT_DIR} = shift;
    if ( !defined($self->{GIT_DIR}) ) {
        croak("No git dir defined!");
    } elsif ( -e $self->{GIT_DIR} && ! -d $self->{GIT_DIR} ) {
        croak("$self->{GIT_DIR} exist but it's not a directory!");
    }

    return $self;
#    return bless({}, $self);
}

sub validate {
    my $self = shift;
    my $mval = shift;
    chdir($self->{GIT_DIR}) or return;
    `git log -1` or return;
    return 1;
}

sub create {
    my $self = shift;
    my $source = shift;
    my $opts = shift;
    my $git_opts = '';
    if ( defined($opts->{'bare'}) && $opts->{'bare'} > 0 ) {
        $git_opts .= ' --bare ';
    }
    system('mkdir','-p',$self->{GIT_DIR});
    chdir($self->{GIT_DIR});
    if (defined($source)) {
        system('git ' . 'clone ' . $git_opts . $source . ' ' . $self->{GIT_DIR});
    } else {
        system('git ' . 'init ' . $git_opts);
    }
}

sub set_remote {
    my $self = shift;
    my $remote_name = shift;
    my $remote_url = shift;
    if ( !defined($remote_url) ) {
        carp("set_remote needs both remote name and remote url");
    }
    $self->_chdir;
    # TODO be smart, if exists use set-url
    system('git', 'remote', 'rm', $remote_name);
    system('git', 'remote', 'add', $remote_name, $remote_url);
}

sub pull {
    my $self = shift;
    $self->_chdir;
    system('git', 'pull');
    if ($?) {
        carp("git pull terminated with error");
        return $? / 256;
    }
}

sub fetch {
    my $self = shift;
    $self->_chdir;
    system('git', 'fetch');
    if ($?) {
        carp("git fetch terminated with error");
        return $? / 256;
    }
}

sub checkout {
    my $self = shift;
    my $branch = shift;
    $self->_chdir;
    if ( !defined($branch) ) {
        croak("checkout needs branch");
    }
    system('git', 'checkout', $branch);
    if ($?) {
        carp("git branch terminated with error");
        return $? / 256;
    }
}

sub push {
    my $self = shift;
    my $c = shift;
    my $target = 'origin';
    my $branch = undef;
    $self->_chdir;
    my $cmd = 'git push';
    if (defined($c->{'target'}) ) {
        my $target = $c->{'target'};
    }
    $cmd .= " $target";
    if ( defined($c->{'branch'}) ) {
        $cmd .= " $c->{'branch'}"
    }
    system($cmd);
    if ($?) {
        carp("git push terminated with error");
    }
    return $? / 256;


}

sub _chdir {
    my $self = shift;
    if ( !chdir($self->{GIT_DIR}) ) {
        carp ("can't chdir to " . $self->{GIT_DIR});
        return 1
    }
    return 0
}

sub _system {
    my $self = shift;
    my $prog = shift;
    my $args = shift;
    my $msg = shift;
    my $failed;
    if (!defined($prog)) {
        croak "no program given";
    }
    if (ref \$args eq 'SCALAR') {
        if (!system($prog, $args)) {
            $failed = 1;
        }
    } elsif (ref \$args eq 'ARRAY') {
        if (!system($prog, \$args)) {
            $failed = 1;
        }
    } else {
        carp ("Bad parameters");
    }
    if ($failed) {
        $msg .= "Failed execution of $prog with args:" . Dumper $args;
        carp ($msg);
        return 1;
    }
    return 0
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

DPP::VCS::Git - Perl extension for blah blah blah

=head1 SYNOPSIS

  use DPP::VCS::Git;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for DPP::VCS::Git, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

xani, E<lt>xani@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by xani

This library is free software; you can redistribute it and/or modify
  it under the same terms as Perl itself, either Perl version 5.12.3 or,
  at your option, any later version of Perl 5 you may have available.


  =cut
