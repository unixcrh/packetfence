package pfws::Model::Graph;
use Moose;
use namespace::autoclean;

use constant INSTALL_DIR => '/root/src/packetfence.git';
use lib INSTALL_DIR . "/lib";

use Date::Parse;
use pf::pfcmd q/field_order/;

extends 'Catalyst::Model';

=head1 NAME

pfws::Model::Graph - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;


# This function has dirtied my soul.  I beg forgiveness for the disgusting code that follows.
# I need a brillo pad and a long, long shower...

sub results {
    my ( $self, $graph, $interval ) = @_;
    require Date::Parse;

    my $function = \&{"pf::pfcmd::graph::graph_$graph"};
    $interval = 'day' unless (defined($interval));

    my @data = ();
    # TOTAL HACK, but we avoid using yet another module
    my %months = (
        "01" => "31",
        "02" => "28",
        "03" => "31",
        "04" => "30",
        "05" => "31",
        "06" => "30",
        "07" => "31",
        "08" => "31",
        "09" => "30",
        "10" => "31",
        "11" => "30",
        "12" => "31"
    );

    my @results;
    if ($function) {
        @results = $function->($interval);
    } else {
        print "No such sub $function\n";
        exit;
    }

    my %series;
    foreach my $result (@results) {
        next if ( $result->{'mydate'} =~ /0000/ );
        my $s = $result->{'series'};
        push( @{ $series{$s} }, $result );
    }
    my @fields = field_order();
    push @fields, keys( %{ $results[0] } ) if ( !scalar(@fields) );
    #print join( "|", @fields ) . "\n";
    push(@data, \@fields);

    #determine first and last time in all series
    my $first_time = undef;
    my $last_time  = undef;
    foreach my $s ( keys(%series) ) {
        my $start_year;
        my $start_mon = 1;
        my $start_day = 1;
        my $end_year;
        my $end_mon = 1;
        my $end_day = 1;
        my @results = @{ $series{$s} };
        if ( $interval eq "day" ) {
            ( $start_year, $start_mon, $start_day )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon, $end_day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "month" ) {
            ( $start_year, $start_mon )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "year" ) {
            $start_year = $results[0]->{'mydate'};
            $end_year   = $results[ scalar(@results) - 1 ]->{'mydate'};
        }
        my $start_time = Date::Parse::str2time(
            "$start_year-$start_mon-$start_day" . "T00:00:00.0000000" );
        my $end_time = Date::Parse::str2time(
            "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
        if ( ( !defined($first_time) ) || ( $start_time < $first_time ) ) {
            $first_time = $start_time;
        }
        if ( ( !defined($last_time) ) || ( $end_time > $last_time ) ) {
            $last_time = $end_time;
        }
    }

    #add, if necessary, first and last time entries to all series
    foreach my $s ( keys(%series) ) {
        my $start_year;
        my $start_mon = 1;
        my $start_day = 1;
        my $end_year;
        my $end_mon = 1;
        my $end_day = 1;
        my @results = @{ $series{$s} };
        if ( $interval eq "day" ) {
            ( $start_year, $start_mon, $start_day )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon, $end_day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "month" ) {
            ( $start_year, $start_mon )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "year" ) {
            $start_year = $results[0]->{'mydate'};
            $end_year   = $results[ scalar(@results) - 1 ]->{'mydate'};
        }
        my $start_time = Date::Parse::str2time(
            "$start_year-$start_mon-$start_day" . "T00:00:00.0000000" );
        my $end_time = Date::Parse::str2time(
            "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
        if ( $start_time > $first_time ) {
            my $new_record;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    $new_record->{$field} = POSIX::strftime( "%Y/%m/%d",
                        localtime($first_time) );
                } elsif ( $field eq "count" ) {
                    $new_record->{$field} = 0;
                } else {
                    $new_record->{$field}
                        = $results[ scalar(@results) - 1 ]->{$field};
                }
            }
            unshift( @{ $series{$s} }, $new_record );
        }
        if ( $end_time < $last_time ) {
            my $new_record;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    $new_record->{$field} = POSIX::strftime( "%Y/%m/%d",
                        localtime($last_time) );
                } else {
                    $new_record->{$field}
                        = $results[ scalar(@results) - 1 ]->{$field};
                }
            }
            push( @{ $series{$s} }, $new_record );
        }
    }

    foreach my $s ( keys(%series) ) {
        my @results = @{ $series{$s} };
        my $year    = POSIX::strftime( "%Y", localtime );
        my $month   = POSIX::strftime( "%m", localtime );
        my $day     = POSIX::strftime( "%d", localtime );
        my $date;
        if ( $interval eq "day" ) {
            $date = "$year/$month/$day";
        } elsif ( $interval eq "month" ) {
            $date = "$year/$month";
        } elsif ( $interval eq "year" ) {
            $date = "$year";
        } else {
        }
        if ( $results[ scalar(@results) - 1 ]->{'mydate'} ne $date ) {
            my %tmp = %{ $results[ scalar(@results) - 1 ] };
            $tmp{'mydate'} = $date;
            push( @results, \%tmp );
        }
        push( @results, $results[0] ) if ( scalar(@results) == 1 );
        if ( $interval eq "day" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ( $start_year, $start_mon, $start_day )
                    = split( /\//, $results[$r]->{'mydate'} );
                my ( $end_year, $end_mon, $end_day )
                    = split( /\//, $results[ $r + 1 ]->{'mydate'} );
                my $start_time
                    = Date::Parse::str2time(
                          "$start_year-$start_mon-$start_day"
                        . "T00:00:00.0000000" );
                my $end_time = Date::Parse::str2time(
                    "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
                for (
                    my $current_time = $start_time;
                    $current_time < $end_time;
                    $current_time += 86400
                    )
                {
                    my @values;
                    foreach my $field (@fields) {
                        if ( $field eq "mydate" ) {
                            push(
                                @values,
                                POSIX::strftime(
                                    "%m/%d/%Y", localtime($current_time)
                                )
                            );
                        } else {
                            push( @values, $results[$r]->{$field} );
                        }
                    }
                    #print join( "|", @values ) . "\n";
                    push(@data, \@values);
                }
            }
            my ( $year, $mon, $day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push(
                        @values,
                        join( "/",
                            sprintf( "%02d", $mon ),
                            sprintf( "%02d", $day ),
                            sprintf( "%02d", $year ) )
                    );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            #print join( "|", @values ) . "\n";
            push(@data, \@values);

        } elsif ( $interval eq "month" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ( $start_year, $start_mon )
                    = split( /\//, $results[$r]->{'mydate'} );
                my ( $end_year, $end_mon )
                    = split( /\//, $results[ $r + 1 ]->{'mydate'} );
                my $mstart = $start_mon;
                for ( my $i = $start_year; $i <= $end_year; $i++ ) {
                    my $mend;
                    if ( $i == $end_year ) {
                        $mend = $end_mon;
                    } else {
                        $mend = "12";
                    }
                    for ( my $ii = $mstart; $ii <= $mend; $ii++ ) {
                        if ( !( $i == $end_year && $ii == $end_mon ) ) {
                            my @values;
                            foreach my $field (@fields) {
                                if ( $field eq "mydate" ) {
                                    push(
                                        @values,
                                        join( "/",
                                            sprintf( "%02d", $ii ),
                                            sprintf( "%02d", $i ) )
                                    );
                                } else {
                                    push( @values, $results[$r]->{$field} );
                                }
                            }
                            #print join( "|", @values ) . "\n";
                            push(@data, \@values);
                        }
                    }
                    $mstart = 1;
                }
            }
            my ( $year, $mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push(
                        @values,
                        join( "/",
                            sprintf( "%02d", $mon ),
                            sprintf( "%02d", $year ) )
                    );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            #print join( "|", @values ) . "\n";
            push(@data, \@values);
        } elsif ( $interval eq "year" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ($start_year) = $results[$r]->{'mydate'};
                my ($end_year)   = $results[ $r + 1 ]->{'mydate'};
                for ( my $i = $start_year; $i <= $end_year; $i++ ) {
                    if ( !( $i == $end_year ) ) {
                        my @values;
                        foreach my $field (@fields) {
                            if ( $field eq "mydate" ) {
                                push( @values, sprintf( "%02d", $i ) );
                            } else {
                                push( @values, $results[$r]->{$field} );
                            }
                        }
                        #print join( "|", @values ) . "\n";
                        push(@data, \@values);
                    }
                }
            }
            my ($year) = $results[ scalar(@results) - 1 ]->{'mydate'};
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push( @values, sprintf( "%02d", $year ) );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            #print join( "|", @values ) . "\n";
            push(@data, \@values);
        }
    }
    
    return \@data;
}

1;
