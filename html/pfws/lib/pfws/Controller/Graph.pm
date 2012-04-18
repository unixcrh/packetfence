package pfws::Controller::Graph;
use Moose;
use namespace::autoclean;

use constant INSTALL_DIR => '/root/src/packetfence.git';
use lib INSTALL_DIR . "/lib";

use Date::Parse;
use pf::pfcmd::graph;
use pf::ifoctetslog;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

pfws::Controller::Graph - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

bin/pfcmd::graph
bin/pfcmd::print_graph_results
lib/pf/pfcmd/graph::graph_unregistered

/graph/ifoctetshistoryuser/<interval>/<startdate>/<enddate>
/graph/ifoctetshistorymac/<interval>/<startdate>/<enddate>
/graph/unregistered/<interval>/
/graph/registered/
/graph/violations/
/graph/nodes/
=head1 METHODS

=head2 ifoctetshistoryuser

Action path : /graph/ifoctetshistoryuser/<pid>/<starttime>/<endtime>

=cut

sub ifoctetshistoryuser :Local :Args(3) {
  my ($self, $c, $pid, $starttime, $endtime) = @_;
  
  my %params = ('start_time' => str2time($starttime),
                'end_time'   => str2time($endtime));
  my @results = ifoctetslog_graph_user($pid, %params);
  my @history = (['count', 'mydate', 'series']);
  foreach my $set (@results) {
    push(@history, [$set->{'throughPutIn'}, $set->{'mydate'}, 'in']);
    push(@history, [$set->{'throughPutOut'}, $set->{'mydate'}, 'out']);
  }

  $c->stash->{result} = \@history;
}

sub ifoctetshistorymac :Local :Args(3) {
  my ($self, $c, $mac, $starttime, $endtime) = @_;

  my %params = ('start_time' => str2time($starttime),
                'end_time'   => str2time($endtime));
  my @results = ifoctetslog_graph_mac($mac, %params);
  my @history = (['count', 'mydate', 'series']);
  foreach my $set (@results) {
    push(@history, [$set->{'throughPutIn'}, $set->{'mydate'}, 'in']);
    push(@history, [$set->{'throughPutOut'}, $set->{'mydate'}, 'out']);
  }

  $c->stash->{result} = \@history;
}

sub ifoctetshistoryswitch :Local :Args(4) {
  my ($self, $c, $mac, $ifIndex, $starttime, $endtime) = @_;

  my %params = ('ifIndex'    => $ifIndex,
                'start_time' => str2time($starttime),
                'end_time'   => str2time($endtime));
  my @results = ifoctetslog_graph_switchport($mac, %params);
  my @history = (['count', 'mydate', 'series']);
  foreach my $set (@results) {
    push(@history, [$set->{'throughPutIn'}, $set->{'mydate'}, 'in']);
    push(@history, [$set->{'throughPutOut'}, $set->{'mydate'}, 'out']);
  }

  $c->stash->{result} = \@history;
}

sub registered :Local {
  my ($self, $c, $interval) = @_;

  my $result = $c->model('Graph')->results($c->action->name, $interval);

  $c->stash->{result} = $result;
  #$c->detach('interval_graph', [$interval]);
#sub interval_graph :Private {
#}
}

sub unregistered :Local {
  my ($self, $c, $interval) = @_;
  
  my $result = $c->model('Graph')->results($c->action->name, $interval);

  $c->stash->{result} = $result;
}

sub violations :Local {
  my ($self, $c, $interval) = @_;
  
  my $result = $c->model('Graph')->results($c->action->name, $interval);

  $c->stash->{result} = $result;
}

sub nodes :Local {
  my ($self, $c, $interval) = @_;
  
  my $result = $c->model('Graph')->results($c->action->name, $interval);

  $c->stash->{result} = $result;
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
