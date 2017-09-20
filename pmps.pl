#!/usr/bin/perl -w
use strict;
use v5.20;
use Pod::Usage;
use Getopt::Long;
use IO::Socket::Multicast;
use IO::Interface::Simple;
$/=1;

my ($m_a,$m_p,$size) = ('224.0.1.75', 5060, 10240);
my ($mif, $srv, $V) = ('', '', 0);
my %pat = ( mac=>'sip:MAC(.*?)\@', lip=>'Via: SIP.*? ([\d\.]+):', ven=>'vend.r="(.*?)"',
mod=>'model="(.*?)"', ver=>'version="(.*?)"', to=>'^(To:.*?)$', from=>'^(From:.*?)$',
cid=>'^(Call-ID:.*?)$', via=>'^(Via:.*?)$', cseq=>'^CSeq: (\d+)' );
my $url = 'http://$srv/pmps/?hw=$mod&fw=$ver&mac=$mac&ip=$ip';

GetOptions( 'help'=>sub{pod2usage(-input=>"$0.pod",-exitval=>0,-verbose=>2)},
"verbose+"=>\$V, "url=s"=>\$url, "srver=s"=>\$srv, "interface=s"=>\$mif );

unless ($mif) {
	$mif = (IO::Interface::Simple->interfaces)[1];
	say "# int: $mif" if $V;
}
$srv ||= (IO::Interface::Simple->new($mif))->address;
say "# $m_a:$m_p $mif:$srv $url" if $V;

my $S=IO::Socket::Multicast->new(LocalPort=>$m_p, LocalAddr=>$m_a, ReuseAddr=>1) or die "$m_p $!";
$S->mcast_add($m_a, $mif) or die "Couldn't multicast add $m_a $mif: $!\n";

while(1) {
	my $D; $S->recv($D,$size) or warn "# recv: $!"; $D =~ tr/\r//d;
	print "# multicast from ".
		$S->peerhost.':'.$S->peerport.' to '.
		$S->sockhost.':'.$S->sockport. "\n" if $V;
	print $D if $V > 1;
	next unless $D =~ /^SUBSCRIBE sip:/;

	# phone params, ip from socket (may be nat'ed)
	my %p = ( ip=>$S->peerhost, mif=>$mif, srv=>$srv );
	$p{$_} = ( $D =~ /$pat{$_}/m ) ? $1 : '' foreach keys %pat;
	say "# $p{mac} $p{lip} $p{ven} $p{mod} $p{ver} $p{cid}" if $V;

	my $T = IO::Socket::INET->new(Proto=>'udp', PeerAddr=>$p{ip}, PeerPort=>$m_p)
		or die "Could not create socket $p{ip}:$m_p $!";
	my $cseq = $p{cseq} + 1; # Send OK
	my $OK = "SIP/2.0 200 OK\r\n$p{via}\r\nContact: <sip:$p{ip}:$m_p>\r\n".
		"$p{to}\r\n$p{from}\r\n$p{cid}\r\nCSeq: $cseq SUBSCRIBE\r\n".
		"Expires: 0\r\nContent-Length: 0\r\n\r\n";
	print "# OK:\n".$OK if $V > 1;
	$T->send($OK) or warn "Can't send OK to $p{ip} $!";

	$url =~ s { \$\{?([\w\-]+)\}? } { $p{$1}||'' }gex;	# rewrite
	$cseq++;	# Send NOTIFY
	my $NFY = "NOTIFY sip:$p{ip}:$m_p SIP/2.0\r\n$p{via}\r\nMax-Forwards: 20\r\n".
	"$p{to}\r\n$p{from}\r\n$p{cid}\r\nCSeq: $cseq NOTIFY\r\n".
	"Content-Type: application/url\r\n".
	"Subscription-State: terminated;reason=timeout\r\n".
	'Event: ua-profile;profile-type="device";vendor="OEM";model="OEM";version="1"'."\r\n".
	"Content-Length: ".length($url)."\r\n\r\n".$url;
	print "# NFY:\n$NFY\n" if $V > 1;
	$T->send ($NFY) or warn "Can't send NOTIFY to $p{ip} $!";
}
