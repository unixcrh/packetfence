package pf::SNMP::Cisco::Catalyst_4500;

=head1 NAME

pf::SNMP::Cisco::Catalyst_4500 - Object oriented module to access and configure Cisco Catalyst 4500 switches

=head1 STATUS

This module is currently only a placeholder, see pf::SNMP::Cisco::Catalyst_2960.

We do not know the minimum required firmware version.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use Try::Tiny;

use pf::accounting qw(node_accounting_current_sessionid);
use pf::config;
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_coa perform_disconnect);

use base ('pf::SNMP::Cisco::Catalyst_2960');

sub description { 'Cisco Catalyst 4500 Series' }

=item handleReAssignVlanTrapForWiredMacAuth

Called when a ReAssignVlan trap is received for a switch-port in Wired MAC Authentication.

Default behavior is to bounce the port 

=cut
sub handleReAssignVlanTrapForWiredMacAuth {
    my ($this, $ifIndex,$mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # TODO extract that behavior in a method call in pf::vlan so it can be overridden easily


    # TODO perform CoA instead (when implemented)
    # actually once CoA will be implemented, we should consider offering the same option to users
    # as we currently do with port-security and VoIP which is bounce or not bounce and suffer consequences
    # this should be a choice exposed in configuration and not hidden in code
    my $acctsessionid = node_accounting_current_sessionid($mac);
    $this->radiusDisconnect($mac ,{ 'Acct-Terminate-Cause' => 'Admin-Reset'});
}

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS CoA-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $management_network->tag('vip'),
        };

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        my $node_info = node_attributes($mac);
        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_coa($connection_info, $attributes_ref, [{ 'vendor' => 'Cisco', 'attribute' => 'Cisco-AVPair', 'value' => 'subscriber:command=reauthenticate' }]);

    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item getIfIndexByNasPortId

Fetch the ifindex on the switch by NAS-Port-Id radius attribute

=cut
 
sub getIfIndexiByNasPortId {
    my ($this, $ifDesc_param) = @_;

    if ( !$this->connectRead() ) {
        return 0;
    }

    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';
    my $ifDescHashRef;
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        if ( $ifDesc =~ /$ifDesc_param$/i ) {
            $key =~ /^$OID_ifDesc\.(\d+)$/;
            return $1;
        }
    }
}


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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

