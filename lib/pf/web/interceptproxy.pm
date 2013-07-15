package pf::web::interceptproxy;

=head1 NAME

interceptproxy.pm

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(OK DECLINED HTTP_MOVED_TEMPORARILY);
use Apache2::RequestRec ();
use Apache2::RequestUtil;
use Apache2::Connection;
use Apache2::URI;

use APR::URI;
use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::util;
use pf::web::util;
#use pf::web::constants;

use constant BUFF_LEN => 1024;

=head1 SUBROUTINES

=over

=item translate

Intercept proxy requests to forward them to the captive portal.

=cut
sub translate {
    my ($r) = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->warn("hitting interceptor with URL: " . $r->uri);
    #Fetch the captive portal URL
    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    my $url = "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};

    my $parsed_portal = APR::URI->parse($r->pool, $url);
    my $parsed_request = APR::URI->parse($r->pool, $r->uri);

    #in case of a Get request to another site than the captive portal, we redirect the request to the captive portal
    if ( $parsed_request->scheme eq 'http' ) {
        if ($parsed_portal->hostname ne $parsed_request->hostname) {
            $logger->info("HTTP request redirect");
            $r->err_headers_out->set('Location' => $parsed_portal->unparse);
            $r->content_type('text/html');
            $r->no_cache(1);
            return Apache2::Const::HTTP_MOVED_TEMPORARILY;
        }
    }

    #in case of a CONNECT request we redirect the request to the reverse proxy
     elsif ( $parsed_portal->hostname ne $parsed_request->scheme ) {
            $logger->info("CONNECT request to reverseproxy");
            $r->parsed_uri->hostname('127.0.0.1');
            $r->parsed_uri->port('444');
            $r->uri('127.0.0.1:444');
            $r->pnotes( 'url_to_mod_proxy' => $r->uri );
            $r->handler('modperl');
            #Def FixupHandler
            $r->set_handlers(PerlFixupHandler => \&fixup);
            return Apache2::Const::OK;
    }

    #The request match with the captive portal URL


    #If it is an http request -> Forward to the captive portal

    if ( $parsed_request->scheme eq 'http' ) {
        my $session_cook = pf::web::util::getcookie($r->headers_in->{Cookie});
        #If there is a session cookie then push the remote ip in the session and redirect to the captive portal
        if ($session_cook) {
            my (%session_id);
            pf::web::util::session(\%session_id,$session_cook);
            $session_id{remote_ip} = $r->connection->remote_ip;
            my $uri = $parsed_portal->unparse;
            $logger->info("http request redirect to captive portal");
            $r->err_headers_out->set('Location' => $uri);
            $r->content_type('text/html');
            $r->no_cache(1);
            return Apache2::Const::HTTP_MOVED_TEMPORARILY;
        }
        #if there is no cookie then proxy to captive portal
        else {
            $logger->warn($r->uri);
            $parsed_portal->scheme(undef);
            $parsed_portal->scheme('http');
            $logger->warn("DEBUG: ".$parsed_portal->unparse.$parsed_request->rpath);
            $r->pnotes( 'url_to_mod_proxy' => $parsed_portal->unparse.$parsed_request->rpath );
       }
    } else {

    #If it is a connect request -> forward to the reverse proxy
        $r->parsed_uri->hostname('127.0.0.1');
        $r->parsed_uri->port('444');
        my $url = "127.0.0.1:444";
        $r->uri($url);
        $r->pnotes( 'url_to_mod_proxy' => $r->uri );
    }
    #Forward to mod_proxy
    $r->handler('modperl');
    $r->set_handlers(PerlFixupHandler => \&fixup);
    return Apache2::Const::OK;
}

=item rewrite

Rewrite Location header to Packetfence captive portal.

=cut

sub rewrite {
    my $f = shift;
    my $r = $f->r;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    if ($r->content_type =~ /text\/html(.*)/) {
        unless ($f->ctx) {
            my @valhead = $r->headers_out->get('Location');
            my $value = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
            my $replacementheader = $r->hostname;
            my $headval;
            foreach $headval (@valhead) {
                if ($headval && $headval =~ /$value/x) {
                    $headval =~ s/$value/$replacementheader/ig;
                    $r->headers_out->unset('Location');
                    $r->headers_out->set('Location' => $headval);
                }
            }
        }
        my $ctx = $f->ctx;
        while ($f->read(my $buffer, BUFF_LEN)) {
            $ctx->{data} .= $buffer;
            $ctx->{keepalives} = $f->c->keepalives;
            $f->ctx($ctx);
        }
        # Thing we do at end
        if ($f->seen_eos) {
            # Dump datas out
            $f->print($f->ctx->{data});
        }
        return Apache2::Const::OK;
    } else {
        return Apache2::Const::DECLINED;
    }
}


=item fixup

Last Handler and last chance to do something in the request

=cut

sub fixup {
    my $r = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    if($r->pnotes('url_to_mod_proxy')){
        return proxy_redirect($r, $r->pnotes('url_to_mod_proxy'));
    }
}

=item proxy_redirect

Mod_proxy redirect

=cut

sub proxy_redirect {
        my ($r, $url) = @_;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__);
        $r->set_handlers(PerlResponseHandler => []);
        $r->filename("proxy:".$url);
        $r->proxyreq(2);
        $r->handler('proxy-server');
        return Apache2::Const::OK;
}


=item

Reverse proxy TransHandler

=cut
sub reverse {
    my $r = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    my $parsed_request = APR::URI->parse($r->pool, $r->uri);
    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    my $url = "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
    my $parsed_portal = APR::URI->parse($r->pool, $url);
    $parsed_portal->scheme(undef);
    $parsed_portal->scheme('http');
    my $session_cook = pf::web::util::getcookie($r->headers_in->{Cookie});

    #If session cookie exist then we can set X-Forwarded-For and proxy to the captive portal
    if ($session_cook) {
        my (%session_id);
        pf::web::util::session(\%session_id,$session_cook);
        if ($session_id{remote_ip}) {
            $r->headers_in->set('X-Forwarded-For' => $session_id{remote_ip});
            $r->headers_in->set('Host' => $Config{'general'}{'hostname'});
            my $url = "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
            $parsed_portal->scheme('https');
            my $url_proxy = $parsed_portal->unparse.$r->uri;
            return proxy_redirect($r, $url_proxy);
        }
        #Cookie is invalid delete it
        else {
            $r->err_headers_out->add('Set-Cookie' => "packetfence=".$session_id{_session_id}."; expires=Thu, 01-Jan-70 00:00:01 GMT; domain=".$parsed_portal->hostname."; path=/");
            $r->err_headers_out->set('Location' => $parsed_portal->unparse);
            $r->content_type('text/html');
            $r->no_cache(1);
            return Apache2::Const::HTTP_MOVED_TEMPORARILY;
        }

    }
    #No session, create one and redirect to http portal to catch the remote ip
    else {
        my (%session_id);
        pf::web::util::session(\%session_id);
        $r->err_headers_out->add('Set-Cookie' => "packetfence=".$session_id{_session_id}."; domain=".$parsed_portal->hostname."; path=/");
        $r->err_headers_out->set('Location' => $parsed_portal->unparse);
        $r->content_type('text/html');
        $r->no_cache(1);
        return Apache2::Const::HTTP_MOVED_TEMPORARILY;
    }
}

=back

=head1 AUTHOR

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT
Copyright (C) 2012 Inverse inc.

=head1 LICENSE
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.
=cut
1;

