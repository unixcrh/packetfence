package pf::cmd::subcmd;
=head1 NAME

pf::cmd::subcmd add documentation

=cut

=head1 DESCRIPTION

pf::cmd::subcmd


=head1 TODO

Have the module loaded dynamically

=cut

use strict;
use warnings;
use pf::cmd;
use base qw(pf::cmd);
use Module::Load;
use pf::cmd::help;

sub run {
    my ($self) = @_;
    my ($cmd,@args);
    if(@{$self->{args}}) {
        @args = @{$self->{args}};
        my $action = shift @args;
        $cmd = $self->getCmd($action);
    } else {
        $cmd = $self->defaultCmd;
    }
    return $cmd->new( {parentCmd => $self, args => \@args})->run;
}

sub getCmd {
    my ($self,$action) = @_;
    my $cmd;
    if (defined $action) {
        my $module;
        if($action eq 'help') {
            $module = $self->helpCmd;
        } else {
            my $base = ref($self) || $self;
            $module = "${base}::${action}";
        }
        eval {
            load $module;
            $cmd = $module;
        };
    }
    unless($cmd) {
        $cmd = $self->unknownCmd;
        load $cmd;
    }
    return $cmd;
}

sub helpCmd { "pf::cmd::help" }

sub unknownCmd {
    my ($self) = @_;
    return $self->defaultCmd;
}

sub defaultCmd { "pf::cmd::help" }



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

