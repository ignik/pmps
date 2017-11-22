#!/usr/bin/perl -w
use strict; use v5.20; # all scripts must fit into a sheet
use Pod::Usage; use Getopt::Long; use IO::Socket::Multicast; use IO::Interface::Simple;
$|++; # autoflush stdout

my $URL = 'http://$srv/pmps/?pmps=$pmpsip&hw=$mod&fw=$ver&mac=$mac&ip=$ip';
my ($m_a, $m_p, $size, $mif, $srv, $V) = ('224.0.1.75', 5060, 10240, '', '', 0);
my %pat = ( mac=>'sip:MAC(.*?)\@', lip=>'Via: SIP.*? ([\d\.]+):', ven=>'vend.r="(.*?)"',
mod=>'model="(.*?)"', ver=>'version="(.*?)"', to=>'^(To:.*?)$', from=>'^(From:.*?)$',
cid=>'^(Call-ID:.*?)$', via=>'^(Via:.*?)$', cseq=>'^CSeq: (\d+)' );

GetOptions('help'=>sub{pod2usage(-input=>"$0.pod",-exitval=>0,-verbose=>2)},
"verbose+"=>\$V, "url=s"=>\$URL, "server=s"=>\$srv, "interface=s"=>\$mif);
my $myaddr = (IO::Interface::Simple->new($mif))->address; 
$mif ||= (IO::Interface::Simple->interfaces)[1]; # get multicast interface if not defined
$srv ||= $myaddr; # get '$srv' if not defined
$/=1, say "# $mif/$m_a:$m_p $srv $URL" if $V;

# listen new multicast $m_a:$m_p via $mif
my $S=IO::Socket::Multicast->new(LocalPort=>$m_p, LocalAddr=>$m_a, ReuseAddr=>1) or die "$m_p $!";
$S->mcast_add($m_a, $mif) or die "Couldn't multicast add $m_a $mif: $!\n";

while(1) { # wait SUBSCRIBE packet
	my $D; $S->recv($D,$size) or warn "# recv: $!"; $D =~ tr/\r//d; # delete "\r" in SUBSCRIBE
	say "# multicast ".$S->peerhost.':'.$S->peerport.' to '.$S->sockhost.':'.$S->sockport if $V;
	next unless $D =~ /^SUBSCRIBE sip:/; print $D if $V > 1;

	# phone params, ip from socket (may be nat'ed)
	my %p = (ip=>$S->peerhost, mif=>$mif, srv=>$srv, pmpsip=>$myaddr); # all trash to hash
	$p{$_} = ($D =~ /$pat{$_}/m) ? $1 : '' foreach keys %pat; # hack SUBSCRIBE to par's
	say "# $p{mac} $p{lip} $p{ven} $p{mod} $p{ver} $p{cid}" if $V; # some debug about results

	my $cseq = $p{cseq} + 1; # Send OK packet
	my $T = IO::Socket::INET->new(Proto=>'udp', PeerAddr=>$p{ip}, PeerPort=>$m_p)
		or die "Could not create socket $p{ip}:$m_p $!";
	my $OK = join "\r\n", ('SIP/2.0 200 OK', "Contact: <sip:$p{ip}:$m_p>", 'Expires: 0',
		$p{via}, $p{to}, $p{from}, $p{cid}, "CSeq: $cseq SUBSCRIBE", 'Content-Length: 0', '');
	$T->send($OK) or warn "Can't send OK to $p{ip} $!"; print "# OK:\n$OK" if $V > 1;

	$cseq++;	# Send NOTIFY packet
	( my $U = $URL ) =~ s { \$\{?([\w\-]+)\}? } { $p{$1}||'' }gex;	# rewrite $URL by %p keys/values
	my $NFY = join "\r\n", ("NOTIFY sip:$p{ip}:$m_p SIP/2.0", 'Max-Forwards: 20',
		$p{via}, $p{to}, $p{from}, $p{cid}, "CSeq: $cseq NOTIFY",
		'Subscription-State: terminated;reason=timeout', 'Content-Type: application/url',
		'Event: ua-profile;profile-type="device";vendor="OEM";model="OEM";version="1"',
		'Content-Length: '.length($U), '', $U);
	$T->send($NFY) or warn "Can't send NOTIFY to $p{ip} $!"; say "# NFY:\n$NFY" if $V > 1;
}
