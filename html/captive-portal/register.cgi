#!/usr/bin/perl

=head1 NAME

register.cgi 

=head1 SYNOPSYS

Handles captive-portal authentication, /status, de-registration, multiple registration pages workflow and viewing AUP

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::iplog;
use pf::locationlog;
use pf::node;
use pf::nodecategory;
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::custom; # called last to allow redefinitions

use pf::authentication;
use pf::Authentication::constants;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('register.cgi');
Log::Log4perl::MDC->put('proc', 'register.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();
my $mac = $portalSession->getClientMac();

# we need a valid MAC to identify a node
if ( !valid_mac($mac) ) {
  $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
  pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
  exit(0);
}

$logger->info($portalSession->getClientIp() . " - " . $portalSession->getClientMac() . " on registration page");

my %info;

# Pull username
$info{'pid'} = $cgi->remote_user || "admin";

# Pull browser user-agent string
$info{'user_agent'} = $cgi->user_agent;

my ($form_return, $err) = pf::web::validate_form($portalSession);
if ($form_return != 1) {
    $logger->trace("form validation failed or first time for " . $portalSession->getClientMac());
    pf::web::generate_login_page($portalSession, $err);
    exit(0);
}

my $pid = $info{'pid'};
my $params = { username => $pid };

my $locationlog_entry = locationlog_view_open_mac($mac);
if ($locationlog_entry) {
    $params->{connection_type} = $locationlog_entry->{'connection_type'};
    $params->{SSID} = $locationlog_entry->{'ssid'};
}

$logger->trace("Assign role 'default' for connection");
%info = (%info, (category => 'default'));

pf::web::web_node_register($portalSession, $pid, %info);
pf::web::end_portal_session($portalSession);

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

