package pf::cmd::action_cmd;
=head1 NAME

pf::cmd::action_cmd add documentation

=cut

=head1 DESCRIPTION

pf::cmd::action_cmd

=cut

use strict;
use warnings;
use base qw(pf::cmd);

sub checkArgs {
    my ($self) = @_;
    my ($action,@args) = $self->args;
    if($self->is_valid_action($action)) {
        $self->{action} = $action;
        return $self->parseArgs(@args);
    }
    return 0;
}

sub parseArgs {
    my ($self,@args) = @_;
    my $action = $self->{action};
    my $parse_action = "parse_$action";
    if ($self->can($parse_action)) {
        return $self->$parse_action;
    }
    $self->{action_args} = \@args;
    return 1;
}

sub is_valid_action {
    my ($self,$action) = @_;
    return $self->can("action_$action");
}

sub _run {
    my ($self) = @_;
    my $action = $self->{action};
    my $method = "action_$action";
    return $self->$method;
}

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

