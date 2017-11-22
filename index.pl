#!/usr/bin/perl -w
#
# https://github.com/ignik/pmps hardware specific configuration
# cgi called 'hw=HardWare' and exec ./hardware/index.pl script
#
use strict;
use CGI qw(:all);
use File::Basename;
chdir dirname $0;

undef $ENV{PATH};

sub bug ($) { print header, start_html, $_[0], end_html, "\n"; exit; }
my $hw = lc ( param('hw') || '' );
bug "incorrect hw $hw" unless $hw =~ /(\w[\w\-]*)/;	# must have letters
my $cmd = "$1/index.pl";
$cmd ? exec ($cmd, @ARGV) : bug "No file $cmd";
