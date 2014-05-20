#!/usr/bin/env perl

use strict;
use inc::Module::Install;

name     'www-bbb-perl';
all_from 'lib/WWW/BBB/API.pm';

requires 'URI';
requires 'Digest::SHA';
requires 'XML::Simple';
requires 'LWP::Simple';

WriteAll;
