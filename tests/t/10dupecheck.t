#
# Test duplicate detection capability
#

use Test;
BEGIN { plan tests => 28 + 4 };
use runproduct;
use istest;
use Ham::APRS::IS;
ok(1); # If we made it this far, we're ok.

# initialize and start the product up
my $p = new runproduct('basic');

ok(defined $p, 1, "Failed to initialize product runner");
ok($p->start(), 1, "Failed to start product");

# create two connections to the server:
# - i_tx for transmitting packets
# - i_rx for receiving packets

my $login = "N5CAL-1";
my $server_call = "TESTING";
my $i_tx = new Ham::APRS::IS("localhost:55580", $login);
ok(defined $i_tx, 1, "Failed to initialize Ham::APRS::IS");

my $i_rx = new Ham::APRS::IS("localhost:55152", "N5CAL-2");
ok(defined $i_rx, 1, "Failed to initialize Ham::APRS::IS");

my $ret;
$ret = $i_tx->connect('retryuntil' => 8);
ok($ret, 1, "Failed to connect to the server: " . $i_tx->{'error'});
$ret = $i_rx->connect('retryuntil' => 8);
ok($ret, 1, "Failed to connect to the server: " . $i_rx->{'error'});

# do the actual tests

my $data = 'foo';

# 8: First, send a non-APRS packet and see that it goes through.
#
# istest::txrx( $okref, $transmit_connection, $receive_connection,
#	$transmitted_line, $expected_line_on_rx );
#
istest::txrx(\&ok, $i_tx, $i_rx,
	"SRC>DST,qAR,$login:$data",
	"SRC>DST,qAR,$login:$data");

# 9: Send the same packet again immediately and see that it is dropped.
# The 1 in as the 6th parameter means that the dummy helper packet is
# also transmitted after the second packet, and that it is the only
# packet which should come out.
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST,qAR,$login:$data", # should drop
	"SRC>DST:dummy", 1); # will pass (helper packet)

# 10: source callsign should be case sensitive - verify that a lower-case
# callsign gets through
istest::txrx(\&ok, $i_tx, $i_rx,
	"src>DST,qAR,$login:$data",
	"src>DST,qAR,$login:$data");

# 11: send the same packet with a different digi path and see that it is dropped
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST,DIGI1*,qAR,$login:$data", # should drop
	"SRC>DST:dummy", 1); # will pass (helper packet)

# 12: send the same packet with a different Q construct and see that it is dropped
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST,$login,I:$data", # should drop
	"SRC>DST:dummy", 1); # will pass (helper packet)

# 13: send the same packet with a different dstcall SSID and see that it is dropped
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST-2,$login,I:$data", # should drop
	"SRC>DST:dummy2", 1); # will pass (helper packet)

# 14: send the same packet with additional whitespace in the end, should pass umodified
istest::txrx(\&ok, $i_tx, $i_rx,
	"SRC>DST,$login,I:$data  ",
	"SRC>DST,qAR,$login:$data  ");

# 15: send the same packet with a different destination call, should pass
istest::txrx(\&ok, $i_tx, $i_rx,
	"SRC>DST2,DIGI1*,qAR,$login:$data",
	"SRC>DST2,DIGI1*,qAR,$login:$data");

######
# 16: send a packet with some whitespace in, the end, then test that the
# whitespace-trimmed version is dropped
istest::txrx(\&ok, $i_tx, $i_rx,
	"SRC>DST2,DIGI1*,qAR,$login:xxx ",
	"SRC>DST2,DIGI1*,qAR,$login:xxx ");

# 17: make sure the whitespace-version gets dropped
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST2,DIGI1*,qAR,$login:xxx",
	"SRC>DST:dummy3", 1); # will pass (helper packet)

######
# 18: send a packet with some 8-bit binary data, test that trimmed packets are dropped
istest::txrx(\&ok, $i_tx, $i_rx,
	"SRC>DST2,qAR,$login:latin1 \xC5\xC4\xD6 skandit",
	"SRC>DST2,qAR,$login:latin1 \xC5\xC4\xD6 skandit");

# 19: removed
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST2,qAR,$login:latin1  skandit",
	"SRC>DST:latin1 dummy1", 1); # will pass (helper packet)

# 20: replaced with spaces
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST2,qAR,$login:latin1     skandit",
	"SRC>DST:latin1 dummy2", 1); # will pass (helper packet)

# 21: 8th bit trimmed
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST2,qAR,$login:latin1 \x45\x44\x56 skandit",
	"SRC>DST:latin1 dummy3", 1); # will pass (helper packet)

######
# 22 send a packet with some low chars (< 0x20), test that trimmed packets are dropped
istest::txrx(\&ok, $i_tx, $i_rx,
	"SRC>DST3,qAR,$login:lowdata \x1C\x1D\x1Fend",
	"SRC>DST3,qAR,$login:lowdata \x1C\x1D\x1Fend");

# 23: removed
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST3,qAR,$login:lowdata end",
	"SRC>DST:low dummy1", 1); # will pass (helper packet)

# 24: replaced with spaces
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST3,qAR,$login:lowdata    end",
	"SRC>DST:low dummy2", 1); # will pass (helper packet)

######
# 25 send a packet with some DEL chars (< 0x7f), test that trimmed packets are dropped
istest::txrx(\&ok, $i_tx, $i_rx,
	"SRC>DST3,qAR,$login:del \x7F\x7Fend",
	"SRC>DST3,qAR,$login:del \x7F\x7Fend");

# 26: removed
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST3,qAR,$login:del end",
	"SRC>DST:del dummy1", 1); # will pass (helper packet)

# 27: replaced with spaces
istest::should_drop(\&ok, $i_tx, $i_rx,
	"SRC>DST3,qAR,$login:del   end",
	"SRC>DST:del dummy2", 1); # will pass (helper packet)

######
# 28: send a really long packet, and then a dupe copy
my $long = "SRC>LONG,qAR,$login:long ";
$long .= "a" x (509-length($long));
istest::txrx(\&ok, $i_tx, $i_rx, $long, $long);

# 29: duplicate copy
istest::should_drop(\&ok, $i_tx, $i_rx,
	$long,
	"SRC>LONG:long dummy", 1); # will pass (helper packet)

# disconnect

$ret = $i_rx->disconnect();
ok($ret, 1, "Failed to disconnect from the server: " . $i_rx->{'error'});
$ret = $i_tx->disconnect();
ok($ret, 1, "Failed to disconnect from the server: " . $i_tx->{'error'});

# stop

ok($p->stop(), 1, "Failed to stop product");

