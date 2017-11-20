#!/usr/bin/perl -w
use strict;
use CGI qw(:all);
undef $ENV{PATH};

sub bug ($) { print header, start_html, $_[0], end_html; exit; }
my $hw = lc (param('hw') || ''); # onl
bug "incorrect hw $hw" unless $hw =~ /(\w[\w\-]*)/;
my $cmd = "./$1.pl";
exit if $cmd eq 'index.pl';
exec ($cmd, @ARGV) if -x $cmd;
bug "No provisioning for $hw";
