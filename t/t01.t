#!/usr/bin/env perl

use utf8;
use open qw(:std :utf8);

use strict;
use warnings;

use Test::More;

use FindBin;
use lib ($FindBin::Bin . '/../lib');

BEGIN {

    use_ok('URI');
    use_ok('Net::Ping'); # core module
    use_ok('LWP::UserAgent');
    use_ok('Merchanta::SMS::Gorod');
}

my $sms = new_ok('Merchanta::SMS::Gorod::HTTP' => ['user' => 'username', 'pass' => 'password']);

SKIP: {

	skip('object creation failed', 2) unless $sms;

	skip('network failed',         1) unless Net::Ping->new()->ping("smsgorod.ru");

	is($sms->send('79010000001', 'test'), Merchanta::SMS::Gorod::HTTP::ERROR_INVALID_USER, 'send()');
}

done_testing();
