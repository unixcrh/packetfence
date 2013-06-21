package pf::Authentication::Source::SQLSource;

=head1 NAME

pf::Authentication::Source::SQLSource

=head1 DESCRIPTION

=cut

use pf::config qw($TRUE $FALSE);
use pf::temporary_password;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Source;

use Moose;
extends 'pf::Authentication::Source';

has '+type' => ( default => 'SQL' );

=head1 METHODS

=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes; 
  my $own_attributes = [{ value => "username", type => $Conditions::STRING }];

  return [@$super_attributes, @$own_attributes];
}

=head2 authenticate

=cut

sub authenticate {  
   my ( $self, $username, $password ) = @_;

   my $result = pf::temporary_password::validate_password($username, $password);

   if ($result == $pf::temporary_password::AUTH_SUCCESS) {
     return ($TRUE, 'Successful authentication using SQL');
   }

   return ($FALSE, 'Unable to authenticate successfully using SQL.');
 }

=head2 match

The SQLSource class overrides the match method of the Source parent class.

It has no conditions and therefore acts as a catchall as long as the username is found
in the temporary_password table.

The actions are defined in the temporary_password table and can be modified for each user
through the web admin interface.

=cut

sub match {
    my ($self, $params) = @_;
    my $common_attributes = $self->common_attributes();

    my $result = pf::temporary_password::view($params->{'username'});
    
    # User is defined in SQL source, let's build the actions and return that
    if (defined $result) {

        my @actions = ();
        my $action;

        my $access_duration = $result->{'access_duration'};
        if (defined $access_duration) {
            $action =  pf::Authentication::Action->new({type => $Actions::SET_ACCESS_DURATION,
                                                        value => $access_duration});
            push(@actions, $action);
        }

        my $access_level = $result->{'access_level'};
        if ($access_level > 0) {
            $action =  pf::Authentication::Action->new({type => $Actions::SET_ACCESS_LEVEL,
                                                        value => $access_level});
            push(@actions, $action);
        }
        
        my $sponsor = $result->{'sponsor'};
        if ($sponsor == 1) {
            $action =  pf::Authentication::Action->new({type => $Actions::MARK_AS_SPONSOR,
                                                        value => 1});
            push(@actions, $action);
        }
        
        my $unregdate = $result->{'unregdate'};
        if (defined $unregdate) {
            $action =  pf::Authentication::Action->new({type => $Actions::SET_UNREG_DATE,
                                                        value => $unregdate});
            push(@actions, $action);
        }
       
        my $category = $result->{'category'};
        if (defined $category) {
            $action =  pf::Authentication::Action->new({type => $Actions::SET_ROLE,
                                                        value => $category});
            push(@actions, $action);
        }

        return \@actions;
    }
    
    return undef;
}

=head2 username_from_email

=cut

sub username_from_email {
    my ( $self, $email ) = @_;

    my $logger = Log::Log4perl->get_logger('pf::authentication');

    return pf::temporary_password::match_by_mail($email);

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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
