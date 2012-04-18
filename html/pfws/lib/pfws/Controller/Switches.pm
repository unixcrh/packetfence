package pfws::Controller::Switches;
use Moose;
use namespace::autoclean;
use JSON;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

pfws::Controller::Switches - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->forward('get', ['all', 'get']);
}

=head2 object

Chained dispatch for a switch.

=cut

sub object :Chained('/') :PathPart('switches') :CaptureArgs(1) {
  my ($self, $c, $section) = @_;

  unless ($c->model('Switches')->sectionExists($section)) {
    $c->res->status(404);
    $c->stash->{result} = "Unknown switch $section";
    $c->detach();
  }
  
  $c->stash->{section} = $section;
}

=head2 get

/switches/<section>/get

=cut

sub get :Chained('object') :PathPart('get') :Args(0) {
  my ($self, $c) = @_;
  my $section = $c->stash->{section};

  my $result;
  eval {
    $result = $c->model('Switches')->get($section);
  };
  if ($@) {
    chomp $@;
    $c->res->status(500);
    $c->stash->{result} = $@;
  }
  else {
    $c->res->status(200);
    $c->stash->{switches} = $result;
  }
}

=head2 delete

/switches/<ip>/delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
  my ($self, $c) = @_;
  my $section = $c->stash->{section};

  my $result;
  eval {
    $result = $c->model('Switches')->remove($section);
  };
  if ($@) {
    chomp $@;
    $c->res->status(500);
    $c->stash->{result} => $@;
  }
  else {
    $c->res->status(200);
    $c->stash->{result} = $result;
  }
}

=head2 edit

/switches/<ip>/edit

=cut

sub edit :Chained('object') :PathPart('edit') :Args(0) {
  my ($self, $c) = @_;
  my $section = $c->stash->{section};

  my $assignments = $c->request->params->{assignments};

  if ($assignments) {
    my $result;
    eval {
      $assignments = decode_json($assignments);
    };
    if ($@) {
      # Malformed JSON
      chomp $@;
      $c->res->status(400);
      $c->stash->{result} = $@;
    }
    else {
      eval { $result = $c->model('Switches')->edit($section, $assignments); };
      if ($@) {
        chomp $@;
        $c->res->status(500);
        $c->stash->{result} = $@;
      }
      else {
        $c->res->status(201);
        $c->stash->{result} = $result;
      }
    }
  }
  else {
    $c->res->status(400);
    $c->stash->{result} => 'Missing parameters';
  }
}

=head2 add

/switches/add/<ip>

=cut

sub add :Local {
  my ($self, $c, $section) = @_;

  my $assignments = $c->request->params->{assignments};

  if ($assignments) {
    my $result;
    eval {
      $assignments = decode_json($assignments);
    };
    if ($@) {
      # Malformed JSON
      chomp $@;
      $c->res->status(400);
      $c->stash->{result} = $@;
    }
    else {
      eval { $result = $c->model('Switches')->add($section, $assignments); };
      if ($@) {
        chomp $@;
        $c->res->status(500);
        $c->stash->{result} = $@;
      }
      else {
        $c->res->status(201);
        $c->stash->{result} = $result;
      }
    }
  }
  else {
    $c->res->status(400);
    $c->stash(message => 'Missing parameters');
    $c->forward('View::HTML');
  }
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
