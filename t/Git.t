# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl DPP.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;
use Data::Dumper;
use lib 'lib/';
use Test::More tests => 4;
BEGIN { use_ok('DPP::VCS::Git') };


# TODO generate random tmp dir
my $testdir = '/tmp/dpp-gitt';
system('rm -rf /tmp/dpp-gitt');
mkdir($testdir);
mkdir("$testdir/1");
chdir($testdir . '/1');
system('git init >/dev/null 2>&1');
system('git config receive.denyCurrentBranch ignore >/dev/null 2>&1');
system('git commit --allow-empty -m test >/dev/null 2>&1');
system('git clone ' . $testdir . '/1 ' . $testdir . '/2 >/dev/null 2>&1');
system('git commit --allow-empty -m test2 >/dev/null 2>&1');




my $git;
eval {
    $git = DPP::VCS::Git->new($testdir . '/2')
};

is($@, '', "module init");
print Dumper $@;

print "asasasasasasas " . $git->push;
is($git->pull, 0, "git pull");

chdir($testdir . '/2');
system('git commit --allow-empty -m test3');

is($git->push, 0, "git push");


#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

