package pfappserver::Controller::Authentication;

=head1 NAME

pfappserver::Controller::Authentication - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

use pf::log;
use pf::authentication;
use pfappserver::Form::Authentication;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 SUBROUTINES

=head2 index

Show list of authentication sources. Allow user to order the list.

/authentication/index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    my ($sources, $types, $form);

    (undef, $sources) = $c->model('Config::Authentication')->readAll();
    $types = availableAuthenticationSourceTypes();
    $form = pfappserver::Form::Authentication->new(ctx => $c,
                                                   init_object => {sources => $sources});
    $form->process();

    $c->stash(
        types => $types,
        form => $form,
        template => 'configuration/authentication.tt'
    );
}

=head2 update

Update the authentication sources order.

/authentication/update

=cut

sub update :Path('update') :Args(0) {
    my ($self, $c) = @_;

    my ($form, $status, $message);
    $c->stash->{current_view} = 'JSON';

    $form = $c->form("Authentication");
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $message = $form->field_errors;
    }
    else {
        my $model = $c->model('Config::Authentication');
        ($status, $message) = $model->sortItems($form->value->{sources});
        if(is_success($status)) {
            $self->_commitChanges($c,$model);
        }
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $message; # TODO: localize error message

}



=head2 _commitChanges

Commit changes would want to refactor to model
#Would need to refactor to the model

=cut

sub _commitChanges {
    my ($self,$c,$model) = @_;
    my $logger = get_logger();
    my ($status,$message);
    eval {
        ($status,$message) = $model->commit();
    };
    if($@) {
        $status = HTTP_INTERNAL_SERVER_ERROR;
        $message = $@;
    }
    if(is_error($status)) {
        $c->stash(
            current_view => 'JSON',
            status_msg => $message,
        );
        $model->rollback();
    }
    $logger->info($message);
    $c->response->status($status);
}

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
