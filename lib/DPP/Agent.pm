package DPP::Agent;

use 5.010000;
use strict;
use warnings;
use Carp qw(cluck croak carp);
use Data::Dumper;
use Log::Any qw($log);
use Symbol qw(gensym);
use IPC::Open3;
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration   use DPP::Agent ':all';
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
    my $cfg = shift;
    $self->{'cfg'} = $cfg;
    $self->{'cfg'}{'puppet_module_path'} = $self->generate_module_path;
    my $main_repo;
    if (defined $cfg->{'manifest_from'} ) {
        $main_repo =  $cfg->{'manifest_from'};
    }
    elsif (defined $cfg->{'use_repos'}[0]) {
        $main_repo =  $cfg->{'use_repos'}[0];
    }
    elsif ( scalar keys %{ $cfg->{'repo'} } == 1 ) {
        ($main_repo) = keys(%{ $cfg->{'repo'} });
    }
    else {
        croak("If you have more than one repo defined you HAVE to set use_repos with proper order (main one first)");
    }
    $cfg->{'puppet_main_repo'}= $cfg->{'repo_dir'} . '/' . $main_repo;
    return $self;
}

sub run_puppet {
    my $self = shift;
    my $out = gensym;
     $log->notice("Running Puppet");
     my $pid = open3(undef, $out, $out,'puppet',  'apply', '-v',
                    '--modulepath=' . $self->{'cfg'}{'puppet_module_path'},
                    $self->{'cfg'}{'puppet_main_repo'} . '/puppet/manifests/site.pp') or carp ("Can't start puppet: $!");
    while (my $line = <$out>) {
        if ($line =~ /^err/) {
            $log->err($line);
        }
        if ($line =~ /^warn/) {
            $log->warning($line);
        }
        elsif ($line =~ /^notice/) {
            $log->notice($line);
        }
        else {
            $log->info($line);
        }
    }
    waitpid( $pid, 0 );
    my $exit_value = $? >> 8;
    $log->notice("Puppet run finished");
    if($exit_value > 0) {
        return;
    }
    else {
        return 1;
    }
}
sub generate_module_path {
    my $self = shift;
    my @puppet_module_path;
    foreach(@{ $self->{'cfg'}{'use_repos'} }) {
        push(@puppet_module_path, $self->{'cfg'}{'repo_dir'} . '/' . $_ . '/modules');
    }
    return join(':',@puppet_module_path);
}

sub ensure_link {
    my $self = shift;
    my $source = shift;
    my $target = shift;
    $source =~ s/\/$//;
    $target =~ s/\/$//;
    if (! -e $source) {
        croak("Link source $source does not exist!");
    }
    if (! -e $target) {
        symlink($source, $target);
        $log->notice("Hiera symlink $target => $source does not exist => created");
        return
    }

    if (-l $target) {
        my (undef, $source_inode) = stat($source);
        my (undef, $target_inode) = stat($target);
        if ($source_inode eq $target_inode) {
            $log->info("Hiera symlink $target => $source OK");
        } else {
            $log->notice("Hiera symlink pointing to wrong dir, relinkin $target => $source");
            unlink($target);
            symlink($source, $target);
        }
    } else {
        croak ("Can't create hiera symlink, target $target isn't a symlink, remove it and retry");
    }
};

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

DPP::Agent - Perl extension for blah blah blah

=head1 SYNOPSIS

  use DPP::Agent;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for DPP::Agent, created by h2xs. It looks like the
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
