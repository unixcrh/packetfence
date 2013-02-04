package pf::Authentication::Source::LDAPSource;

=head1 NAME

pf::Authentication::Source::LDAPSource

=head1 DESCRIPTION

=cut

use pf::config qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::Authentication::Condition;

use Net::LDAP;

use Moose;
extends 'pf::Authentication::Source';

# available encryption
use constant {
        NONE => "none",
        SSL => "ssl",
	TLS => "tls",
      };

has '+type' => ( default => 'LDAP' );
has 'host' => (isa => 'Maybe[Str]', is => 'rw', default => '127.0.0.1');
has 'port' => (isa => 'Maybe[Int]', is => 'rw', default => 389);
has 'basedn' => (isa => 'Str', is => 'rw', required => 1);
has 'binddn' => (isa => 'Str', is => 'rw', required => 1);
has 'password' => (isa => 'Str', is => 'rw', required => 1);
has 'encryption' => (isa => 'Str', is => 'rw', required => 1);
has 'scope' => (isa => 'Str', is => 'rw', required => 1);
has 'usernameattribute' => (isa => 'Str', is => 'rw', required => 1);

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @ldap_attributes = map { { value => $_, type => $Conditions::STRING } }
    ("cn", "department", "displayName", "distinguishedName", "givenName", "memberOf", "sn");

  # We check if our username attribute is present, if not we add it.
  if (not grep {$_->{value} eq $self->usernameattribute} @ldap_attributes ) {
    push (@ldap_attributes, { value => $self->{usernameattribute}, type => $Conditions::STRING });
  }

  return [@$super_attributes, @ldap_attributes];
}

sub authenticate {
  my ( $self, $username, $password ) = @_;
  
  my $connection = Net::LDAP->new($self->{'host'});
  
  if (! defined($connection)) {
    return ($FALSE, 'Unable to validate credentials at the moment');
  }

  my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});
  
  if ($result->is_error) {
    return ($FALSE, 'Unable to validate credentials at the moment');
  }
  
  my $filter = "($self->{'usernameattribute'}=$username)";
  $result = $connection->search(
 				base => $self->{'basedn'},
 				filter => $filter,
 				scope => $self->{'scope'},
 				attrs => ['dn']
 			       );
  if ($result->is_error) {
    return ($FALSE, 'Unable to validate credentials at the moment');
  }
  
  if ($result->count != 1) {
    return ($FALSE, 'Invalid login or password');
  }
  
  my $user = $result->entry(0);
  
  $result = $connection->bind($user->dn, password => $password);
  
  if ($result->is_error) {
    return ($FALSE, 'Invalid login or password');
  }

  return ($TRUE, 'Successful authentication using LDAP.');
}

=item match_in_subclass

=cut
sub match_in_subclass {
    
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ );

    my $filter = ldap_filter_for_conditions($own_conditions, $rule->match, $self->{'usernameattribute'}, $params);
    
    my $connection = Net::LDAP->new($self->{'host'});
    if (! defined($connection)) {
        $logger->error("Unable to connect to '$self->{'host'}'");
        return undef;
    }
    
    my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});
    
    if ($result->is_error) {
        $logger->error("Unable to bind with '$self->{'binddn'}'");
        return undef;
    }
    
    $logger->info("Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}");
    $result = $connection->search(
				  base => $self->{'basedn'},
				  filter => $filter,
				  scope => $self->{'scope'},
				  attrs => ['dn']
				 );
    
    if ($result->is_error) {
        $logger->error("Unable to execute search, we skip the rule.");
        next;
    }
    
    if ($result->count == 1) {
        my $dn = $result->entry(0)->dn;
        $connection->unbind;
        $logger->info("Found a match ($dn)! pushing LDAP conditions");
        push @{ $matching_conditions }, @{ $own_conditions };
    }
    
    return undef;
}

=item ldap_filter_for_conditions

This function is used to generate an LDAP filter based on conditions
from a rule.

=cut
sub ldap_filter_for_conditions {
  my ($conditions, $match, $usernameattribute, $params) = @_;

  my $expression = '(';
    
  if ($match eq pf::Authentication::Rule->ANY) {
    $expression .= '|';
  }
  else {
    $expression .= '&';
  }

  foreach my $condition (@{$conditions})  {
    my $str = "";
    
    # FIXME - we should escape things properly
    if ($condition->{'operator'} eq pf::Authentication::Condition->EQUALS) {
      $str = "$condition->{'attribute'}=$condition->{'value'}";
    } elsif ($condition->{'operator'} eq pf::Authentication::Condition->CONTAINS) {
      $str = "$condition->{'attribute'}=*$condition->{'value'}*";
    }
    
    if (scalar @{$conditions}  == 1) {
      $expression = '(' . $str;
    }
    else {
      $expression .= '(' . $str . ')';
    }
  }

  $expression .= ')';
 
  $expression = '(&(' . $usernameattribute . '=' . $params->{'username'} . ')' . $expression .')';
  
  return $expression;
} 

sub username_from_email {
    my ( $self, $email ) = @_;

    my $logger = Log::Log4perl->get_logger('pf::authentication');

    my $filter = "(mail=$email)";

    my $connection = Net::LDAP->new($self->{'host'});
    if (! defined($connection)) {
      $logger->error("Unable to connect to '$self->{'host'}'");
      return undef;
    }
    
    my $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});
    
    if ($result->is_error) {
      $logger->error("Unable to bind with '$self->{'binddn'}'");
      return undef;
    }
    
    $logger->info("Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}");
    $result = $connection->search(
				  base => $self->{'basedn'},
				  filter => $filter,
				  scope => $self->{'scope'},
				  attrs => $self->{'usernameattribute'}
				 );
    
    if ($result->is_error) {
      $logger->error("Unable to execute search, we skip the rule.");
      next;
    }
    
    if ($result->count == 1) {
      my $username = $result->entry->get_value( $self->{'usernameattribute'} );
      $connection->unbind;
      $logger->info("Found a match ($username)");
      return $username;
    }
    
    $logger->info("No match found for filter: $filter");
    return undef;
}

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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