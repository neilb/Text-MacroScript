#!/usr/bin/perl -w

# $Id$

# Copyright (c) 2000 Mark Summerfield. All Rights Reserved.
# May be used/distributed under the GPL.

use strict ;

use vars qw( $Loaded $Count $DEBUG $TRIMWIDTH ) ;

BEGIN { $| = 1 ; print "1..3\n" ; }
END   { print "not ok 1\n" unless $Loaded ; }

use Text::MacroScript ;
$Loaded = 1 ;

$DEBUG = 1,  shift if @ARGV and $ARGV[0] eq '-d' ;
$TRIMWIDTH = @ARGV ? shift : 60 ;

report( "loaded module ", 0, '' ) ;

my $Macro ;

eval {
    $Macro = Text::MacroScript->new ;
} ;
report( 'new', 0, $@ ) ;

eval {
    $Macro = Text::MacroScript->new( -file => [ 'nosuchfile' ] ) ;
} ;
report( 'new', 1, $@ ) ;



sub report {
    my $test = shift ;
    my $flag = shift ;
    my $e    = shift ;

    ++$Count ;
    printf "[%03d] $test(): ", $Count if $DEBUG ;

    if( $flag == 0 and not $e ) {
        print "ok $Count\n" ;
    }
    elsif( $flag == 0 and $e ) {
        $e =~ tr/\n/ / ;
        if( length $e > $TRIMWIDTH ) { $e = substr( $e, 0, $TRIMWIDTH ) . '...' } 
        print "not ok $Count" ;
        print " \a($e)" if $DEBUG ;
        print "\n" ;
    }
    elsif( $flag ==1 and not $e ) {
        print "not ok $Count" ;
        print " \a(error undetected)" if $DEBUG ;
        print "\n" ;
    }
    elsif( $flag ==1 and $e ) {
        $e =~ tr/\n/ / ;
        if( length $e > $TRIMWIDTH ) { $e = substr( $e, 0, $TRIMWIDTH ) . '...' } 
        print "ok $Count" ;
        print " ($e)" if $DEBUG ;
        print "\n" ;
    }
}


