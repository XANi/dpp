#!/usr/bin/perl
use lib '../lib/'; # include local libs
use strict;
use warnings;
use Config::General;
use DPP::VCS::Git;
our $VERSION = '0.01';




my $c = new Config::General(-ConfigFile => glob("dppd.conf"),
                         -MergeDuplicateBlocks => 'true',
                         -MergeDuplicateOptions => 'true',
                         -AllowMultiOptions => 'true'
			);
my %conf = $c->getall;
my $conf =\%conf;



my $p_repo = DPP::VCS::Git->new($conf->{'puppet_repo'});
