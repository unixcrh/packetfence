#!/usr/bin/perl

=head1 NAME

hardware-snmp-objects.t

=head1 DESCRIPTION

pf::SNMP... basic tests

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
my $lib_path = '/usr/local/pf/lib';
use Test::More;
use Test::NoWarnings;

use TestUtils;

my @all_snmp_classes = TestUtils::get_networkdevices_classes();

# test plan: all classes x 2 + no warnings + missing subs
plan tests => scalar @all_snmp_classes* 2 + 2;

foreach my $snmp_class (@all_snmp_classes) {
    use_ok($snmp_class);
    my $snmp_obj = $snmp_class->new();
    isa_ok( $snmp_obj, $snmp_class, $snmp_class);
}

# MockedSwitch is our special test switch that MUST implement all of pf::SNMP's method
# To ensure that it stays always that way, we test for it here.

my @mocked_switch_subs = `egrep "^sub " $lib_path/pf/SNMP/MockedSwitch.pm | awk '{ print \$2 }'`;
my @pf_snmp_subs = `egrep "^sub " $lib_path/pf/SNMP.pm | awk '{ print \$2 }'`;
# these methods are whitelisted because they have no [significant] side-effect, thus not useful to mock
my @whitelist = (
    'new', 'isUpLink', 'setVlanWithName', 'setVlanByName', 'setMacDetectionVlan',
    'getMode', 'isTestingMode', 'isIgnoreMode', 'isRegistrationMode',
    'isProductionMode', 'isDiscoveryMode', 'getBitAtPosition', 'modifyBitmask', 'flipBits',
    'createPortListWithOneItem', 'reverseBitmask', 'generateFakeMac', 'isFakeMac', 'isFakeVoIPMac', 'getVlanFdbId',
    'isNotUpLink', 'setVlan', 'setVlanAllPort', 'getMacAtIfIndex', 'hasPhoneAtIfIndex',
    'isPhoneAtIfIndex', '_authorizeMAC', 'getRegExpFromList', '_getMacAtIfIndex', 'getMacAddrVlan', 'getHubs',
    'getVlanByName', 'isManagedVlan', 'deauthenticateMac', 'setVlan', 'extractSsid', 'supportsWirelessMacAuth',
    'supportsWirelessDot1x', 'authorizeCurrentMacWithNewVlan', '_authorizeCurrentMacWithNewVlan',
    'disableIfLinkUpDownTraps', 'enableIfLinkUpDownTraps', 'connectWrite', 'connectWriteToController',
    'disconnectWrite', 'disconnectWriteToController', 'getDeauthSnmpConnectionKey', '_NasPortToIfIndex',
    'radiusDisconnect', 'supportsRoleBasedEnforcement', 'getRoleByName', 'returnRadiusAccessAccept',
    'synchronize_locationlog'
);

my @missing_subs;
foreach my $sub (@pf_snmp_subs) {

    # skip if pf::SNMP sub is found in mocked_switch
    next if grep {$sub eq $_} @mocked_switch_subs;

    # removing newline to avoid comparison failures
    chop($sub);
    # skip if this sub is in whitelist
    next if grep {$sub eq $_} @whitelist;

    # if we are still here, there's a missing sub in MockedSwitch
    push @missing_subs, $sub;
}

# is deeply will show what's missing from pf::SNMP::MockedSwitch which is kinda nice
is_deeply(
    \@missing_subs,
    [],
    "there must be no sub in pf::SNMP not implemented or whitelisted in pf::SNMP::MockedSwitch"
);

# TODO future MockedWireless module will have to test for: deauthenticateMac, radiusDisconnect

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

