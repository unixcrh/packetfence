package pfws;
use Moose;
use namespace::autoclean;

use Log::Log4perl::Catalyst;
use Catalyst::Runtime 5.90;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use pf::config;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    -Debug
    ConfigLoader
    Static::Simple

    Authentication

    Session
    Session::Store::File
    Session::State::Cookie
/;

extends 'Catalyst';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in pfws.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'pfws',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,

    'View::JSON' => {
       allow_callback  => 1,    # defaults to 0
       callback_param  => 'cb', # defaults to 'callback'
       expose_stash    => [ qw(result error interfaces switches) ], # defaults to everything
    },

    'Plugin::Session' => {
      storage => '/tmp/session'
    },

    'Plugin::Authentication' => {
       default_realm => 'pfws',
       realms => {
         pfws => {
           credential => {
             class => 'HTTP',
             type => 'basic', # digest requires a cache
             password_field => 'password',
             password_type => 'self_check',
           },
           store => {
             class => 'Htpasswd',
             file => '/usr/local/pf/conf/admin.conf', # must exist
#             class => 'Minimal',
#             users => {
#               bob => {
#                 password => "s00p3r",
#                 editor => 'yes',
#                 roles => [qw/edit delete/],
#               },
#               william => {
#                 password => "s3cr3t",
#                 roles => [qw/comment/],
#               }
#             }
           }
         }
       }
     },
);

# Log to packetfence.log
#__PACKAGE__->log(Log::Log4perl::Catalyst->new());

# Start the application
__PACKAGE__->setup();


=head1 NAME

pfws - Catalyst based application

=head1 SYNOPSIS

    script/pfws_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<pfws::Controller::Root>, L<Catalyst>

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
