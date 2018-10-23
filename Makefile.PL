use utf8;
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'              => 'Merchanta::SMS::Gorod',
    'DISTNAME'          => 'Merchanta-SMS-Gorod',
    'LICENSE'           => 'perl',
    'AUTHOR'            => 'dctabuyz@ya.ru',
    'VERSION_FROM'      => 'lib/Merchanta/SMS/Gorod.pm',

    'NO_MYMETA'         => 1,

    'PREREQ_FATAL'      => 1,
    'PREREQ_PM'         => {

        'URI'             => 0,
        'LWP::UserAgent'  => 0,
    },
);
