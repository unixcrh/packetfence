package pfws::Model::Switch;
use Moose;
use namespace::autoclean;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";

use pf::config;
use Config::IniFiles;

my $logger = Log::Log4perl->get_logger(__PACKAGE__);

extends 'Catalyst::Model';

=head1 NAME

pfws::Model::Switch - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my $switches = undef;

__PACKAGE__->meta->make_immutable;

sub _switches_conf {
  my ($self) = @_;

  unless (defined $switches) {
    my %switches_conf;
    tie %switches_conf, 'Config::IniFiles',
      ( -file => "$conf_dir/switches.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) || !%switches_conf) {
      $logger->logdie("Error reading switches.conf: " . join( "\n", @errors ) . "\n" );
    }
    else {
      $switches = \%switches_conf;
    }
  }

  return $switches;
}

sub sectionExists {
  my ($self, $section) = @_;

  return 1 if ($section eq 'all');

  my $switches_conf = $self->_switches_conf();
  my $tied_switch = tied(%$switches_conf);
  return $tied_switch->SectionExists($section);
}

sub get {
  my ($self, $section) = @_;

  my $switches_conf = $self->_switches_conf();
  foreach my $s (tied(%$switches_conf)->Sections ) {
    foreach my $key ( keys %{ $switches_conf->{$s} } ) {
      $switches_conf->{$s}{$key} =~ s/\s+$//;
    }
  }

  # TODO columns should be auto-detected and displayed based on ui.conf (like print_results does)
  my @columns = qw/
            ip type mode VoIPEnabled uplink 
            vlans normalVlan registrationVlan isolationVlan macDetectionVlan guestVlan voiceVlan 
            customVlan1 customVlan2 customVlan3 customVlan4 customVlan5 
            cliTransport cliUser cliPwd cliEnablePwd 
            wsTransport wsUser wsPwd 
            radiusSecret
            controllerIp
            SNMPVersionTrap SNMPCommunityTrap SNMPUserNameTrap 
            SNMPAuthProtocolTrap SNMPAuthPasswordTrap SNMPPrivProtocolTrap SNMPPrivPasswordTrap 
            SNMPVersion SNMPCommunityRead SNMPCommunityWrite 
            SNMPEngineID SNMPUserNameRead SNMPAuthProtocolRead SNMPAuthPasswordRead SNMPPrivProtocolRead 
            SNMPPrivPasswordRead SNMPUserNameWrite SNMPAuthProtocolWrite SNMPAuthPasswordWrite SNMPPrivProtocolWrite 
            SNMPPrivPasswordWrite
            macSearchesMaxNb macSearchesSleepInterval
                  /;

  #sort the switches (http://www.sysarch.com/Perl/sort_paper.html)
  my %switches_conf_tmp = %$switches_conf;
  delete $switches_conf_tmp{'default'};
  my @sections_tmp = keys(%switches_conf_tmp);
  my @sections
    = map substr( $_, 4 ) => sort
      map pack( 'C4' => /(\d+)\.(\d+)\.(\d+)\.(\d+)/ )
        . $_ => @sections_tmp;
  unshift( @sections, 'default' );

  my @resultset = (\@columns);
  foreach my $s (@sections) {
    if (   ( !defined $section ) 
           || ( $section eq 'all' )
           || ( $section eq $s ) )
      {
        my @values;
        foreach my $column (@columns) {
          if ( $column eq 'ip' ) {
            push @values, $s;
          } else {
            push @values,
              (      $switches_conf->{$s}{$column}
                     || $switches_conf->{'default'}{$column}
                     || '' );
          }
        }
        push @resultset, \@values;
      }
  }

  if ($#resultset > 0) {
    return \@resultset;
  }
  else {
    # Section not found
    return undef;
  }
}

sub remove {
  my ($self, $section) = @_;

  if ( $section =~ /^(default|all|127.0.0.1)$/ ) {
    die "This switch can't be deleted";
  } else {
    my $switches_conf = $self->_switches_conf();
    my $tied_switch = tied(%$switches_conf);
    if ( $tied_switch->SectionExists($section) ) {
      $tied_switch->DeleteSection($section);
      $tied_switch->WriteConfig($conf_dir . "/switches.conf")
        or $logger->logdie("Unable to write config to $conf_dir/switches.conf. "
                           ."You might want to check the file's permissions.");
      # The following snippet updates the database
      require pf::configfile;
      import pf::configfile;
      configfile_import( $conf_dir . "/switches.conf" );
    } else {
      # Section not found
      return undef;
    }
  }
  
  return "Successfully deleted $section";
}

sub add {
  my ($self, $section, $assignments) = @_;

  my $switches_conf = $self->_switches_conf();
  my $tied_switch = tied(%$switches_conf);
  if ( !($tied_switch->SectionExists($section)) ) {
    foreach my $assignment (@$assignments) {
      $tied_switch->AddSection($section);
      my ( $param, $value ) = @$assignment;
      if (   ( !exists( $switches_conf->{'default'}{$param} ) )
             || ( $switches_conf->{'default'}{$param} ne $value ) )
        {
          $tied_switch->newval( $section, $param, $value );
        }
    }
    $tied_switch->WriteConfig($conf_dir . "/switches.conf")
      or die "Unable to write config to $conf_dir/switches.conf. "
        ."You might want to check the file's permissions.";
    require pf::configfile;
    import pf::configfile;
    configfile_import( $conf_dir . "/switches.conf" );
  } else {
    die "Switch $section already exists\n";
  }

  return "Successfully created $section";
}

sub edit {
  my ($self, $section, $assignments) = @_;

  my $switches_conf = $self->_switches_conf();
  my $tied_switch = tied(%$switches_conf);
  if ( $tied_switch->SectionExists($section) ) {
    foreach my $assignment (@$assignments) {
      my ( $param, $value ) = @$assignment;
      if ($section eq 'default') {
        if ( defined( $switches_conf->{$section}{$param} ) ) {
          $tied_switch->setval( $section, $param, $value );
        } else {
          $tied_switch->newval( $section, $param, $value );
        }
      } else {
        if ( defined( $switches_conf->{$section}{$param} ) ) {
          if (   ( !exists( $switches_conf->{'default'}{$param} ) )
                 || ( $switches_conf->{'default'}{$param} ne $value ) )
            {
              $tied_switch->setval( $section, $param, $value );
            } else {
              $tied_switch->delval( $section, $param );
            }
        } else {
          if (   ( !exists( $switches_conf->{'default'}{$param} ) )
                 || ( $switches_conf->{'default'}{$param} ne $value ) )
            {
              $tied_switch->newval( $section, $param, $value );
            }
        }
      }
    }
    $tied_switch->WriteConfig($conf_dir . "/switches.conf")
      or $logger->logdie("Unable to write config to $conf_dir/switches.conf. "
                         ."You might want to check the file's permissions.");
    require pf::configfile;
    import pf::configfile;
    configfile_import( $conf_dir . "/switches.conf" );
  } else {
    # Section not found
    return undef;
  }

  return "Successfully modified $section";
}

1;
