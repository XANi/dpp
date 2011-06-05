package DPP::VCS::Git;

use 5.012003;
use strict;
use warnings;
use Carp qw(cluck croak);
use Data::Dumper;
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use DPP::VCS::Git ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

use vars qw( $GIT_DIR );

sub new {
    my $self = shift;
    my $GIT_DIR = shift;
    if ( !defined($GIT_DIR) ) {
	croak "No git dir defined"
    }
    return bless({}, $self);
}

sub pull {
    my $self = shift;
    $self->_chdir;
    if(system('git', 'pull')) {
	return 0;
    } else {
	carp("git pull terminated with error");
	return 1;
    }
}


sub push {
    my $self = shift;
    my $c = shift;
    my $target = 'origin';
    my $branch = undef;
    $self->_chdir;
    my $cmd = 'git push';
    if(defined($c->{'target'}) ) {
	my $target = $c->{'target'};
    }
    $cmd .= " $target";
    if( defined($c->{'branch'}) ) {
	$cmd .= " $c->{'branch'}"
    }


}

sub _chdir {
    if ( !chdir($GIT_DIR) ) {
	carp ("can't chdir to $GIT_DIR");
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
    if (!defined($prog)) {croak "no program given"}
    if(ref \$args eq 'SCALAR') {
	if (!system($prog, $args)) {$failed = 1;}
    }
    elsif(ref \$args eq 'ARRAY') {
	if (!system($prog, \$args)) {$failed = 1;}
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
