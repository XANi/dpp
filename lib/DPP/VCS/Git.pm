package DPP::VCS::Git;

use 5.010000;
use strict;
use warnings;
use Carp qw(cluck croak carp);
use Data::Dumper;
use Log::Any qw($log);
use Symbol qw(gensym);
use IPC::Open3;
use File::Path qw(make_path);
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

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);
    my %cfg = @_;
    $self->{'cfg'} = \%cfg;
    if ( !defined($self->{'cfg'}{'git_dir'}) ) {
        croak("No git dir defined!");
    } elsif ( -e $self->{'cfg'}{'git_dir'} && ! -d $self->{'cfg'}{'git_dir'} ) {
        croak("$self->{'cfg'}{'git_dir'} exist but it's not a directory!");
    }
    if(defined($self->{'cfg'}{'force'}) && $self->{'cfg'}{'force'} <= 0) {
        delete $self->{'cfg'}{'force'};
    }
    $self->{'cfg'}{'branch'} ||= 'master';
    return $self;
}

sub validate {
    my $self = shift;
    my $mval = shift;
    chdir($self->{'cfg'}{'git_dir'}) or return;
    `git log -1` or return;
    return 1;
}

sub create {
    my $self = shift;
    my $source = shift;
    my $opts = shift;
    my $cmd = ['clone'];
    if ( defined($opts->{'bare'}) && $opts->{'bare'} > 0 ) {
        push @$cmd, '--bare';
    }
    make_path($self->{'cfg'}{'git_dir'});
    chdir($self->{'cfg'}{'git_dir'});
    if (defined($source)) {
        push @$cmd, $source;
        push @$cmd, $self->{'cfg'}{'git_dir'};
    }
    $self->_system('git', $cmd, 'info');
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
    $self->_system('git', ['remote', 'rm', $remote_name ]);
    $self->_system('git', ['remote', 'add', $remote_name, $remote_url]);
}

sub pull {
    my $self = shift;
    $self->_chdir;
    $self->_system(
        'git',
        [ 'pull', '--all'],
        'notice',
    );
    if ($?) {
        my $err = $? / 256;
        $log->err("git pull terminated with error code $err");
        return
    }
    return 1
}

sub verify_commit {
    my $self = shift;
    my $commit = shift;
    if ( !defined($self->{'cfg'}{'gpg_id'}) ) {
        return;
    }
    local %ENV;
    $ENV{'LC_ALL'} = 'C';
    $self->_chdir;
    my ($stdin, $stdout);
    my $pid = open3(undef, $stdout, $stdout, 'git', 'log', '--format=%GG', '-1', $commit);
    my $out;
    while(<$stdout>) {
        $out .= _$;
    }
    waitpid( $pid, 0 );
    my $exit_status = $? >> 8;
    if ($exit_status > 0) {
        $log->error("GPG verify error: exit code [ $exit_status ] msg:\n$out\n");
        return;
    }
    my $gpgid;
    if ($out =~ /key ID\s(\S+)\s/) {
        $gpgid = $1;
    }
    else {
        return
    }
    if (grep {/$gpgid/}  $self->{'cfg'}{'gpgid'}) {
        return 1;
    }
    return
}

sub fetch {
    my $self = shift;
    $self->_chdir;
    return $self->_system('git', 'fetch');
}

sub checkout {
    my $self = shift;
    my $branch = shift;
    $self->_chdir;
    if ( !defined($branch) ) {
        croak("checkout needs branch");
    }
    if(defined($self->{'cfg'}{'force'})) {
        $self->_system(
            'git',
            ['reset','--hard', 'origin/' . $branch],
            'notice',
        );
    }
    return $self->_system(
        'git',
        ['checkout', $branch],
        'notice',
    )
}

sub push {
    my $self = shift;
    my $c = shift;
    my $target = 'origin';
    my $branch = undef;
    $self->_chdir;
    my $cmd = ['push'];
    if (defined($c->{'target'}) ) {
        my $target = $c->{'target'};
    }
    push @$cmd, $target;
    if ( defined($c->{'branch'}) ) {
        push @$cmd, $c->{'branch'};
    }
    $self->_system('git', $cmd);
}

sub _chdir {
    my $self = shift;
    if ( !chdir($self->{'cfg'}{'git_dir'}) ) {
        carp ("can't chdir to " . $self->{'cfg'}{'git_dir'});
        return 1
    }
    return 0
}

sub _system {
    my $self = shift;
    my $prog = shift;
    my $args;
    if ( ref($_[0]) eq 'ARRAY') {
        $args = shift;
    }
    elsif (ref $_[0] eq 'SCALAR') {
        $args = [ $_[0] ],
    }
    else {
        $args = \@_;
    }
    my $loglvl = shift;
    # fix for git failin on some GPG operations when LANG is not english
    # because some commands analyze text output from gpg command which change
    # with locale
    local %ENV;
    $ENV{'LC_ALL'} = 'C';

    $loglvl ||= 'info';
    my $failed;
    my $fh_out = gensym;
    if (!defined($prog)) {
        croak "no program given";
    }
    if (ref $args eq 'SCALAR') {
        $args = [ $args ],
    } elsif (ref $args ne 'ARRAY') {
        croak ("Bad parameters");
    }

    my $pid = open3(undef, $fh_out, $fh_out, ($prog, @$args));
    while(<$fh_out>) {
        $log->$loglvl($_);
    }
    my $exit_code = waitpid($pid,0);
    return $exit_code >> 8;
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
