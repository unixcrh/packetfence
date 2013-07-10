package pf::cmd::pf::locationhistorymac;
=head1 NAME

pf::cmd::pf::locationhistorymac add documentation

=head1 SYNOPSIS

pfcmd locationhistorymac mac [date]

get the switch port where a specified MAC connected to with optional date (in mysql format)

examples:
  pfcmd locationhistorymac 00:11:22:33:44:55
  pfcmd locationhistorymac 00:11:22:33:44:55 2006-10-12 15:00:00

=head1 DESCRIPTION

pf::cmd::pf::locationhistorymac

=cut

use strict;
use warnings;
use base qw(pf::cmd::display);
use pf::cmd::roles::show_help;
use pf::locationlog;

sub checkArgs {
    my ($self) = @_;
    my ($key,@date_args) = $self->args;
    if($key) {
        my %params;
        $params{date} = str2time(join(' ',@date_args));
        $params{mac} = $key;
        $self->{function} = \&locationlog_history_mac;
        $self->{key} = $key;
        $self->{params} = \%params;
        return 1;
    }
    return 0;
}

sub field_ui { "locationhistorymac" }


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

