#
# Miscellanious bad packets which should be dropped
#
# 1 - 3rd party packets }
# 2 - generic queries ?
# 3 - TCPIP, TCPXX, NOGATE, RFONLY in path
#

use Test;
BEGIN { plan tests => 8 + 1 + 5 };
use runproduct;
use istest;
use Ham::APRS::IS;
use Time::HiRes qw(sleep);

my $p = new runproduct('basic');

ok(defined $p, 1, "Failed to initialize product runner");
ok($p->start(), 1, "Failed to start product");

my $login = "N5CAL-1";
my $server_call = "TESTING";
my $i_tx = new Ham::APRS::IS("localhost:55580", $login);
ok(defined $i_tx, 1, "Failed to initialize Ham::APRS::IS");

my $i_rx = new Ham::APRS::IS("localhost:55152", "N5CAL-2");
ok(defined $i_rx, 1, "Failed to initialize Ham::APRS::IS");

my $unver_call = "N5UN-1";
my $i_un = new Ham::APRS::IS("localhost:55580", $unver_call, 'nopass' => 1);
ok(defined $i_un, 1, "Failed to initialize Ham::APRS::IS");

my $ret;
$ret = $i_tx->connect('retryuntil' => 8);
ok($ret, 1, "Failed to connect to the server: " . $i_tx->{'error'});

$ret = $i_rx->connect('retryuntil' => 8);
ok($ret, 1, "Failed to connect to the server: " . $i_rx->{'error'});

$ret = $i_un->connect('retryuntil' => 8);
ok($ret, 1, "Failed to connect to the server: " . $i_un->{'error'});

# do the actual tests
my($tx, $rx);

# Test that the unverified client does not manage to transmit anything
# at all.
$tx = "OH2XXX>APRS,qAR,$login:>should drop from unverified client";
$i_un->sendline($tx);
$tx = "$unver_call>APRS,qAR,$unver_call:>should drop from unverified client, 2";
$i_un->sendline($tx);
$tx = "$unver_call>APRS,qAR,$unver_call:!6028.52N/02505.61E# Testing";
$i_un->sendline($tx);

# Other drop reasons
my @pkts = (
	"SRC>APRS,RFONLY,qAR,$login:>should drop, RFONLY",
	"SRC>APRS,NOGATE,qAR,$login:>should drop, NOGATE",
	"SRC>APRS,RFONLY,qAR,$login:>should drop, RFONLY",
	"SRC>DST,DIGI,qAR,$login:}SRC2>DST,DIGI,TCPIP*:>should drop, 3rd party",
	"SRC>DST,DIGI,qAR,$login:}SRC3>DST,DIGI,TCPXX*:>should drop, 3rd party TCPXX",
	"SRC>DST,DIGI,qAR,$login:?APRS? general query",
	"SRC>DST,DIGI,qAR,$login:?WX? general query",
	"SRC>DST,DIGI,qAR,$login:?FOOBAR? general query",
	"SRC>DST\x08,DIGI,qAR,$login:>should drop ctrl-B in dstcall",
	"SRC\x08>DST,DIGI,qAR,$login:>should drop ctrl-B in srccall",
	" SRC>DST,DIGI,qAR,$login:>should drop, space in front of srccall",
	"\x00SRC>DST,DIGI,qAR,$login:>should drop, null in front of srccall",
	"S\\RC>DST,DIGI,qAR,$login:>should drop, backslash in srccall",
	"S\xefRC>DST,DIGI,qAR,$login:>should drop, high byte in srccall",
	"SRCXXXXXXX>APRS,qAR,$login:>should drop, too long srccall",
	"SRC>APRSXXXXXX,qAR,$login:>should drop, too long dstcall",
	"SRC>APRS,OH2DIGI-12,qAR,$login:>should drop, too long call in path",
	"SRC>APT311,RELAY,WIDE,WIDE/V,qAR,$login:!4239.93N/08254.93Wv342/000 should drop, / in digi path",
	"SRC>DST,DIG*I,qAR,$login:>should drop, * in middle of digi call",
	"SRC>DST,DI\x08GI,qAR,$login:>should drop, ctrl-B in middle of digi call",
	"SRC2>DST,DIGI,qAX,$login:>Packet from unverified login according to qAX",
	"SRC2>DST,DIGI,TCPXX,qAR,$login:>Packet from unverified login according to TCPXX in path",
	"SRC2>DST,DIGI,TCPXX*,qAR,$login:>Packet from unverified login according to TCPXX* in path",
	"SRC->DST,DIGI-0,qAR,$login:>should drop, too short SSID in srccall",
# javap4 drops these, javap3 allows, should consider dropping in aprsc too
#	"SRC-111>DST,DIGI,qAR,$login:>should drop, too long SSID in srccall",
#	"E1E-DH5FF>DST,DIGI,qAR,$login:>should drop, much too long SSID in srccall",
#	"EL>DST,DIGI,qAR,$login:>should drop, too short callsign",
#	"EL-1>DST,DIGI,qAR,$login:>should drop, too short callsign before SSID",
# javap3/javap4/aprsc all allow really long srccalls, surprisingly
#	"OH5FFLONG>DST,DIGI,qAR,$login:>should drop, too long srccall",
	# disallowed source callsigns
	"N0CALL>DST,DIGI,qAR,$login:>should drop, N0CALL as source callsign",
	"NOCALL>DST,DIGI,qAR,$login:>should drop, NOCALL as source callsign",
	"NOCALL-1>DST,DIGI,qAR,$login:>should drop, N0CALL-1 as source callsign",
	"SERVER>DST,DIGI,qAR,$login:>should drop, SERVER as source callsign",
	# additionally configured disallowed source callsigns: N7CALL N8CALL
	"N7CALL>DST,DIGI,qAR,$login:>should drop, N7CALL as source callsign matches N7CALL",
	"N8CALL>DST,DIGI,qAR,$login:>should drop, N8CALL as source callsign matches N8CALL*",
	"GLDROP>DST,DIGI,qAR,$login:>should drop, GLDROP as source callsign matches *DROP",
	"DRGLOB>DST,DIGI,qAR,$login:>should drop, DRGLOB as source callsign matches DRG*",
	"OH7DRU>DST,DIGI,qAR,$login:>should drop, OH7DRU as source callsign matches OH?DRUP",
	# DX spots
	"SRC>DST,DIGI,qAR,$login:DX de FOO: BAR - should drop",
	# Disallowed message recipients, status messages and such
	"SRC-2>APRS,qAR,${login}::KIPSS    :KipSS Login:OK1xx-1{16",
	"SRC>APRS,qAR,${login}::javaMSG  :Foo_BAR Linux APRS Server: 192.168.10.72 connected 2 users online.",
);

# send the packets
foreach my $s (@pkts) {
	$i_tx->sendline($s);
}

# check that a packet passes at all and the previous packets were dropped
$tx = "OH2SRC>APRS,OH2DIG-12*,OH2DIG-1*,qAR,200106F8020204020000000000000002,$login:should pass";
$i_tx->sendline($tx);

my $fail = 0;
my $success = 0;
while (my $rx = $i_rx->getline_noncomment(0.5)) {
	if ($rx =~ /should pass/) {
		$success = 1; # ok
	} else {
		warn "Server passed packet it should have dropped: $rx\n";
		$fail++;
	}
}

ok($fail, 0, "Server passed packets which it should have dropped.");
ok($success, 1, "Server did not pass final packet which it should have passed.");

# disconnect

$ret = $i_tx->disconnect();
ok($ret, 1, "Failed to disconnect from the server: " . $i_rx->{'error'});

$ret = $i_tx->disconnect();
ok($ret, 1, "Failed to disconnect from the server: " . $i_tx->{'error'});

$ret = $i_un->disconnect();
ok($ret, 1, "Failed to disconnect from the server: " . $i_un->{'error'});

# stop

ok($p->stop(), 1, "Failed to stop product");



