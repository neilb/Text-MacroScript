package Text::MacroScript ; # Documented at the __END__.

require 5.004 ;

use strict ;

use Carp qw( carp croak ) ;
use Cwd ;
use Symbol () ;

use vars qw( $VERSION ) ;
$VERSION = '2.00'; 


### Object fields
#       -comment
#       -file 
#       -macro 
#       -script 
#       -variable
#       -embedded 
#       -opendelim 
#       -closedelim 

### -which values: -variable -script -macro
 
### Private class data and methods. 
#
#   _expand_variable                object
#   _find_element                   object
#   _insert_element                 object
#   _remove_element                 object


sub _expand_variable { # Private object method.
    my $self  = shift ;
    my $class = ref( $self ) || $self ;
    local $_  = (shift || '') ;

    foreach my $var (  
                sort { 
                    length( $b ) <=> length( $a ) ||
                            $b   cmp         $a 
                    } keys %{$self->{VARIABLE}} 

                ) {
        s/#\Q$var\E/\$Var{"$var"}/msg ;
    }

    $_ ;
}


# This is based on the 'binary_string' function, pg 163 of Mastering
# Algorithms with Perl (with the errata).
sub _find_element { # Private object method.
    my( $self, $array_name, $target ) = @_ ;
    my $class = ref( $self ) || $self ;

    my $target_len    = length $target ;

    my( $low, $high ) = ( 0, scalar @{$self->{$array_name}} ) ;

    while( $low < $high ) {
        use integer ;

        my $index        = ( $low + $high ) / 2 ;

        my $in_array     = $self->{$array_name}->[$index][0] ;
        my $in_array_len = length $in_array ;

        # Order by longest, then by ASCII.
        if( $in_array_len > $target_len or
            ( $in_array_len == $target_len and
              $in_array     lt $target ) ) {
            $low  = $index + 1 ; 
        }
        elsif( $in_array eq $target ) { # This is more efficient than just
            $low  = $index ;            # having the else.
            last ;
        }
        else {
            $high = $index ;
        }
    }

    $low ;
}


sub _insert_element { # Private object method.
    my( $self, $array_name, $name, $body ) = @_ ;
    my $class = ref( $self ) || $self ;

    if( $array_name eq 'VARIABLE' ) {
        $self->{$array_name}{$name} = $body ;
    }
    else {
        my $index = $self->_find_element( $array_name, $name ) ;

        if( $index < @{$self->{$array_name}} and
            $self->{$array_name}->[$index][0] eq $name ) {
            # Already there so replace $body.
            $self->{$array_name}->[$index] = [ $name, $body ] ;
        }
        else {
            # Not there so insert it.
            splice( @{$self->{$array_name}}, $index, 0, [ $name, $body ] ) ;
        }
    }
}


sub _remove_element { # Private object method.
    my( $self, $array_name, $name ) = @_ ;
    my $class = ref( $self ) || $self ;

    my $element = undef ;

    if( $array_name eq 'VARIABLE' ) {
        $element = delete $self->{$array_name}{$name} 
        if exists $self->{$array_name}{$name} ;
    }
    else {
        my $index = $self->_find_element( $array_name, $name ) ;

        if( $index < @{$self->{$array_name}} and
            $self->{$array_name}->[$index][0] eq $name ) {
            $element = splice( @{$self->{$array_name}}, $index, 1 ) ;
        }
    }

    $element ;
}


DESTROY { # Object method
    ; # Noop
}


### Public methods

sub new { # Class and object method
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    # We create a new object from scratch whether called as a class or object
    # method.
    $self = { 
        -comment    => 0,     # Create the %%[] comment macro?
        -file       => [],    # Read macros and scripts from these on creation
        -macro      => [],    # Array of macros    in the form [[name=>body],...]
        -script     => [],    # Array of scripts   in the form [[name=>body],...]
        -variable   => [],    # Array of variables in the form [[name=>value],...]
        -embedded   => 0,     # If true will create default delims if not given
        -opendelim  => undef, # Delimiters used if we are working on embedded
        -closedelim => undef, # macros
        @_ 
        } ;

    @{$self->{MACRO}}    = () ; # Ordered list to hold the macro definitions 
    @{$self->{SCRIPT}}   = () ; # Ordered list to hold the script definitions 
    %{$self->{VARIABLE}} = () ; # Hash to hold the users variables

    $self->{REMOVE}      = 1 ;  # Remove definitions from the output; only an
                                # option for debugging purposes

    # `State' temporaries used during processing
    $self->{IN_MACRO}    = 0 ;  # Are we in a multi-line macro definition?
    $self->{IN_SCRIPT}   = 0 ;  # Are we in a multi-line script definition?
    $self->{IN_CASE}     = 0 ;  # Are we in a %CASE block? 0, 'SKIP' or 1.
    $self->{IN_EMBEDDED} = 0 ;  # Are we in embedded text?
    $self->{DEFINE}      = '' ; # The multi-line macro or script we're building up
    $self->{NAME}        = '' ; # The name of the multi-line macro or script
    $self->{LINO}        = 1 ;  # Current line number (for multi-line
                                # definitions this is always the line number
                                # of the %DEFINE line)
    $self->{OPEN_LEN}    = 0 ; 
    $self->{CLOSE_LEN}   = 0 ; 

    if( $self->{-embedded} or defined $self->{-opendelim} ) {
        # We want embedded, but may want default delimiters.
        $self->{-opendelim}  = "<:" unless $self->{-opendelim} ;
        # If the user has just given an opendelim then use it as closedelim
        # too.
        $self->{-closedelim} = $self->{-opendelim} 
        if not $self->{-closedelim} and $self->{-opendelim} ne "<:" ;

        $self->{-closedelim} = ":>" unless $self->{-closedelim} ; 
        # We process embedded if we have two delimiters.
        $self->{-embedded}   = 1 ;
        $self->{OPEN_LEN}    = length $self->{-opendelim} ; 
        $self->{CLOSE_LEN}   = length $self->{-closedelim} ; 
    }
    
    bless $self, $class ;   # Bless early so we can call methods
    
    eval {
        local $_ ;

        $self->define( -macro, '%%', '' ) if $self->{-comment} ;

        foreach( @{$self->{-file}} ) {
            $self->load_file( $_ ) ;
        }

        foreach( @{$self->{-variable}} ) {
            my( $name, $body ) = @{$_} ;
            $self->define( -variable, $name, $body ) ;
        }

        foreach( @{$self->{-macro}} ) {
            my( $name, $body ) = @{$_} ;
            $self->define( -macro, $name, $body ) ;
        }

        foreach( @{$self->{-script}} ) {
            my( $name, $body ) = @{$_} ;
            $self->define( -script, $name, $body ) ;
        }
    } ;
    croak $@ if $@ ;

    $self ;
}


sub get { # Object method
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    $self->{shift()} ;
}

# No set - use define instead.


sub define { # Object method.
    my( $self, $which, $name, $body ) = @_ ;
    my $class = ref( $self ) || $self ;

    $self->_insert_element( uc substr( $which, 1 ), $name, $body ) ;
}


sub undefine { # Object method.
    my( $self, $which, $name ) = @_ ;
    my $class = ref( $self ) || $self ;

    $which = uc substr( $which, 1 ) ;

    carp "No $which called $name exists" unless 
    $self->_remove_element( $which, $name ) ; 
}


sub list { # Object method.
    my( $self, $which, $namesonly ) = @_ ;
    my $class = ref( $self ) || $self ;

    my @lines ;
    local $_ ;

    $which     = uc substr( $which, 1 ) ;
    my $script = '' ;
    $script    = "_$which" unless $which eq 'MACRO' ;

    my $array ;

    if( $which eq 'VARIABLE' ) {
        $array = [ map { [ $_, $self->{VARIABLE}{$_} ] } 
                    keys %{$self->{VARIABLE}} ] ;
    }
    else {
        $array = $self->{$which} ;
    }

    foreach( @{$array} ) {
        my( $name, $body ) = @{$_} ;
        my $line = "%DEFINE$script $name" ;

        if( $body =~ /\n/o ) {
            $line .= "\n$body%END_DEFINE\n" unless $namesonly ;
        }
        else {
            $line .= " [$body]\n" unless $namesonly ;
        }

        if( wantarray ) {
            push @lines, $line ;
        }
        else {
            print "$line\n" ;
        }
    }

    @lines if wantarray ;
}


sub undefine_all { # Object method.
    my( $self, $which ) = @_ ;
    my $class = ref( $self ) || $self ;

    $which = uc substr( $which, 1 ) ;

    if( $which eq 'VARIABLE' ) {
        %{$self->{$which}} = () ;
    }
    else {
        @{$self->{$which}} = () ;
    }
}


# If we just want to load in a macro file
sub load_file { # Object method.
    my( $self, $file ) = @_ ;
    my $class = ref( $self ) || $self ;

    # Treat loaded files as if wrapped in delimiters (only affects embedded
    # processing).
    my $in_embedded = $self->{IN_EMBEDDED} ; 
    $self->{IN_EMBEDDED} = 1 ; 

    $self->expand_file( $file, -noprint ) ;

    $self->{IN_EMBEDDED} = $in_embedded ; 
}


# Usage: $macro->expand_file( name, body )
# In an array context will return the file, e.g.
# @expanded = $macro->expand_file( name, body ) ;
# In a void context will print to the current filehandle
sub expand_file { # Object method.
    my( $self, $file, $noprint ) = @_ ;
    my $class = ref( $self ) || $self ;

    # We need this because eval creates a scalar context.
    my $wantarray = wantarray ;

    my @lines ;

    eval {
        croak "missing filename"            unless     $file ; 
        croak "file `$file' does not exist" unless  -e $file ;

        substr( $file, 0, 1 ) = ( $ENV{HOME} or $ENV{LOGDIR} or (getpwuid( $> ))[7] ) 
        if substr( $file, 0, 1 ) eq '~' ;

        local $_ ;

        my $fh = Symbol::gensym ;

        open $fh, $file or croak "failed to open $file: $!" ;

        while( <$fh> ) {
            my $line = $self->{-embedded} ? 
                            $self->expand_embedded( $_, $file ) :
                            $self->expand( $_, $file ) ;

            next unless defined $line and $line ; 

            if( $wantarray ) {
                push @lines, $line ;
            }
            else {
                print $line unless $noprint ;
            }
        }

        close $fh or croak "failed to close $file: $!" ;

	if( $self->{IN_MACRO} or $self->{IN_SCRIPT} ) {
	    my $which = $self->{IN_MACRO} ? 'DEFINE' : 'DEFINE_SCRIPT' ;
	    croak "runaway \%$which to end of file"
	}

    } ;
    croak $@ if $@ ;

    @lines if $wantarray and not $noprint ;
}


sub expand_embedded { # Object method.
    my $self  = shift ;
    my $class = ref( $self ) || $self ;
    local $_  = shift ;
    my $file  = (shift || '-') ;

    my $line = '' ;

    if( not $self->{IN_EMBEDDED} and /^$self->{-opendelim}$/o ) {
        $self->{IN_EMBEDDED} = 1 ;
    } 
    elsif( $self->{IN_EMBEDDED} and /^$self->{-closedelim}$/o ) {
        $self->{IN_EMBEDDED} = 0 ;
    }
    elsif( not $self->{IN_EMBEDDED} ) {
        my $pos = index( $_, $self->{-opendelim} ) ;
        if( $pos > -1 ) {
            $line = substr( $_, 0, $pos ) if $pos > 0 ;
            my $start = $pos + $self->{OPEN_LEN} ;
            my $end   = index( $_, $self->{-closedelim}, $start ) ;
            if( $end > -1 ) {
                $line .= $self->expand( 
                    substr( $_, $start, $end - $start ), $file ) ;
                $line .= $self->expand_embedded( 
                            substr( $_, $end + $self->{CLOSE_LEN} ), $file ) ;
            }
            else {
                $line .= $self->expand( substr( $_, $start ), $file ) ;
                $self->{IN_EMBEDDED} = 1 ;
            }
        }
        else {
            $line = $_ ;
        }
    }
    else {
        my $end = index( $_, $self->{-closedelim} ) ;
        if( $end > -1 ) {
            $line = $self->expand( substr( $_, 0, $end ), $file ) ;
            $self->{IN_EMBEDDED} = 0 ;
            $line .= $self->expand_embedded( 
                        substr( $_, $end + $self->{CLOSE_LEN} ), $file ) ;
        }
        else {
            $line = $self->expand( $_, $file ) ;
        }
    }

    $line ;
}


sub expand { # Object method.
    my $self  = shift ;
    my $class = ref( $self ) || $self ;
    local $_  = shift ;
    my $file  = (shift || '-') ;

    $self->{LINO} = $. || 1 unless $self->{IN_MACRO} or $self->{IN_SCRIPT} ;
    my $where     = "at $file line $self->{LINO}" ;

    eval {
        if( /^\%((?:END_)?CASE)(?:\s*\[(.*?)\])?/mso or 
            ( $self->{IN_CASE} eq 'SKIP' ) ) {

            croak "runaway \%DEFINE $where to line $."
            if $self->{IN_MACRO} ;
            croak "runaway \%DEFINE_SCRIPT $where to line $."
            if $self->{IN_SCRIPT} ;

            if( defined $1 and $1 eq 'CASE' ) {
                croak "no condition for CASE $where" unless defined $2 ;

                my $eval    = $self->_expand_variable( $2 ) ;
                my $result ;
                eval {
                    my %Var = %{$self->{VARIABLE}} ;
                    local $_ ;
                    $result = eval $eval ;
                    %{$self->{VARIABLE}} = %Var ;
                } ;
                croak "evaluation of CASE $eval failed $where: $@" if $@ ;

                $self->{IN_CASE} = $result ? 1 : 'SKIP' ;
            }
            elsif( defined $1 and $1 eq 'END_CASE' ) {
                $self->{IN_CASE} = 0 ;
            }

            $_ = '' if $self->{REMOVE} ;
        }
        elsif( ( $self->{IN_MACRO} or $self->{IN_SCRIPT} ) and /^\%END_DEFINE/mso ) {
            # End of a multi-line macro or script
            $self->{DEFINE} = $self->_expand_variable( $self->{DEFINE} ) ;

            my $which = $self->{IN_MACRO} ? 'MACRO' : 'SCRIPT' ;

            $self->{"IN_$which"} = 0 ;
            $self->_insert_element( $which, $self->{NAME}, $self->{DEFINE} ) ;
            $self->{NAME} = $self->{DEFINE} = '' ;

            $_ = '' if $self->{REMOVE} ;
        }
        elsif( $self->{IN_MACRO} or $self->{IN_SCRIPT} ) {
            # Accumulating the body of a multi-line macro or script
            my $which = $self->{IN_MACRO} ? 'DEFINE' : 'DEFINE_SCRIPT' ;
            croak "runaway \%$which $where to line $."
            if /^\%
                (?:(?:UNDEFINE(?:_ALL)|DEFINE)(?:_SCRIPT|_VARIABLE)?) |
                LOAD | INCLUDE | (?:END_)CASE
               /msox ;

            $self->{DEFINE} .= $_ ;

            $_ = '' if $self->{REMOVE} ;
        }
        elsif( /^\%UNDEFINE(?:_(SCRIPT|VARIABLE))?\s+([^][\s]+)/mso ) {
            # Undefining a macro, script or variable
            my $which = $1 || 'MACRO' ;

            carp "Cannot undefine non-existent $which $2 $where" 
            unless $self->_remove_element( $which, $2 ) ; 
     
            $_ = '' if $self->{REMOVE} ;
        }
        elsif( /^\%UNDEFINE_ALL(?:_(SCRIPT|VARIABLE))?/mso ) {
            # Undefining all macros or scripts
            my $which = $1 || 'MACRO' ;

            @{$self->{$which}} = () ;

            $_ = '' if $self->{REMOVE} ;
        }
        elsif( /^\%DEFINE(?:_(SCRIPT|VARIABLE))?\s+([^][\s]+)\s*\[(.*?)\]/mso ) {
            # Defining a single-line macro, script or variable
            my $which = $1 || 'MACRO' ;

            $self->_insert_element( $which, $2, $self->_expand_variable( $3 || '' ) ) ;

            $_ = '' if $self->{REMOVE} ;
        }
        elsif( /^\%DEFINE(?:_(SCRIPT))?\s+([^][\s]+)/mso ) {
            # Preparing to define a multi-line macro or script (we don't permit
            # multi-line variables)
            my $which = defined $1 ? 'SCRIPT' : 'MACRO' ;
            $self->{NAME}        = $2 ;
            $self->{DEFINE}      = '' ;
            $self->{"IN_$which"} = 1 ;

            $_ = '' if $self->{REMOVE} ;
        }
        elsif( /^\%(LOAD|INCLUDE)\s*\[(.+?)\]/mso ) {
            # Save state in local stack frame (i.e. recursion is taking care of
            # stacking for us)
            my $in_macro    = $self->{IN_MACRO} ;   # Should never be true
            my $in_script   = $self->{IN_SCRIPT} ;  # Should never be true
            my $in_case     = $self->{IN_CASE} ;    # Should never be true
            my $define      = $self->{DEFINE} ;
            my $name        = $self->{NAME} ;
            my $lino        = $self->{LINO} ;
            my $in_embedded = $self->{IN_EMBEDDED} ;

            my @lines = () ;
            
            # Load in new stuff
            if( $1 eq 'LOAD' ) {
                # If we are doing embedded processing and we are loading a new
                # file then we assume we are still in the embedded text since
                # we're loading macros, scripts etc.
                carp "Should be embedded when LOADing $2" 
                if $self->{-embedded} and not $self->{IN_EMBEDDED} ;

                # $self->{IN_EMBEDDED} = 1 ; # Should be 1 anyway - this is done

                # inside load_file().
                # This is a macro/scripts file; instantiates macros and scripts,
                # ignores everything else.
                $self->load_file( $2 ) ;
            }
            else {
                # If we are doing embedded processing and we are including a new file
                # then we assume that we are not in embedded text at the start of that
                # file, i.e. we look freshly for an opening delimiter. 
                carp "Should be embedded when INCLUDINGing $2" 
                if $self->{-embedded} and not $self->{IN_EMBEDDED} ;

                $self->{IN_EMBEDDED} = 0 ; # Should be 1, but we want it off now. 

                # This is a normal file that may contain macros/scripts - the
                # macros and scripts are instantiated and any text is returned
                # with all expansions applied
                @lines = $self->expand_file( $2 ) ;
            }
        
            # Restore state
            $self->{IN_MACRO}    = $in_macro ;
            $self->{IN_SCRIPT}   = $in_script ;
            $self->{IN_CASE}     = $in_case ;
            $self->{DEFINE}      = $define ;
            $self->{NAME}        = $name ;
            $self->{LINO}        = $lino ;
            $self->{IN_EMBEDDED} = $in_embedded ;

            # Replace string with the outcome of the load (empty) or include 
            $_ = join '', @lines ;
        }
        elsif( /^\%REQUIRE\s*\[(.+?)\]/mso ) {
            my $file = $1 ;
            eval {
                require $file ;
            } ;
            carp "Failed to require `$file': $@" if $@ ;

            $_ = '' if $self->{REMOVE} ;
        }
        else {
            # This array is already ordered by length then by ASCII.
            foreach my $script ( @{$self->{SCRIPT}} ) {
                my( $name, $orig_body ) = @{$script} ;
                # We substitute wherever found, including in the middle of 'words'
                # or whatever (but we can always create macro names like *MYMACRO
                # which are unlikely to occur in words). 
                # Macro names shouldn't include ] and can't include [.
                s{
                    \Q$name\E
                    (?:\[(.+?)\])?  
                 }{
                    # Get any parameters
                    my @param = split /\|/, $1 if defined $1 ;
                    # We get $body fresh every time since we could have the same
                    # macro or script occur more than once in a line but of course
                    # with different parameters.
                    my $body  = $orig_body ;
                    # Substitute any parameters in the script's body; we go from
                    # largest index to smallest to ensure that we substitute #13
                    # before #1!
                    if( $body =~ /#\d/mso ) {

                        $body =~ s/\\#/\x0/msgo ; # Hide escaped #s

                        # Warnings don't seem to work correctly here so we switch
                        # them off and do them manually.
                        local $^W = 0 ;

                        for( my $i = $#param ; $i >= 0 ; $i-- ) {
                            $body =~ s/#$i/$param[$i]/msg ;
                        }
                        carp "missing parameter or unescaped # in SCRIPT " .
                             "$name $body $where"
                        if ( $#param > 9 and $body =~ /#\d\d\D/mso ) or 
                                           ( $body =~ /#\d\D/mso ) ;

                        $body =~ s/\x0/#/msgo ; # Unhide escaped #s
                        # Extra parameters, i.e. those given in the text but not
                        # used by the macro or script are ignored and do not
                        # appear in the output.
                    }
                    # Evaluate the script 
                    my $result = '' ;
                    eval {
                        my @Param = @param ; # Give (local)  access to params
                        my %Var   = %{$self->{VARIABLE}} ;
                        local $_ ;
                        $result   = eval $body ;
                        %{$self->{VARIABLE}} = %Var ;
                    } ;
                    croak "evaluation of SCRIPT $name failed $where: $@" 
                    if $@ ;
                    # This carp does't work - its supposed to catch a failed eval
                    # and give an error message - instead perl doesn't set $@ but
                    # outputs its own error message immediately instead. Although
                    # we can switch off perl's message using local $^W = 0, doing
                    # so means that the error goes by silently, so I've left the
                    # default behaviour so at least we know we've got an error.
                    # Please let me know how to fix this!

                    # Return the result of the evaluation as the replacement string
                    $result ;
                 }gmsex ; 
            }

            foreach my $macro ( @{$self->{MACRO}} ) {
                my( $name, $body ) = @{$macro} ;

                s{
                    \Q$name\E
                    (?:\[(.+?)\])?  
                 }{
                    my @param = split /\|/, $1 if defined $1 ;
                    {
                        $body =~ s/\\#/\x0/msgo ; # Hide escaped #s

                        local $^W = 0 ;

                        for( my $i = $#param ; $i >= 0 ; $i-- ) {
                            $body =~ s/#$i/$param[$i]/msg ;
                        }

                        carp "missing parameter or unescaped # in MACRO " .
                             "$name $body $where"
                        if ( $#param > 9 and $body =~ /#\d\d\D/mso ) or 
                                           ( $body =~ /#\d\D/mso ) ;

                        $body =~ s/\x0/#/msgo ; # Unhide escaped #s
                    }
                    $body ;
                 }gmsex ; 
            }
        }
    } ;
    croak $@ if $@ ;

    $_ ;
}


1 ;

__END__

=head1 NAME

Text::MacroScript - A macro pre-processor with embedded perl capability 

=head1 SYNOPSIS

    use Text::MacroScript ;

    # new() for macro processing

    my $Macro = Text::MacroScript->new ;
    while( <> ) {
        print $Macro->expand( $_ ) if $_ ;
    }

    # Canonical use (the filename improves error messages):
    my $Macro = Text::MacroScript->new ;
    while( <> ) {
        print $Macro->expand( $_, $ARGV ) if $_ ;
    }

    # new() for embedded macro processing

    my $Macro = Text::MacroScript->new( -embedded => 1 ) ; 
    # Delimiters default to <: and :>
    # or
    my $Macro = Text::MacroScript->new( -opendelim => '[[', -closedelim => ']]' ) ;
    while( <> ) {
        print $Macro->expand_embedded( $_, $ARGV ) if $_ ;
    }

    # Create a macro object and create initial macros/scripts from the file(s)
    # given:
    my $Macro = Text::MacroScript->new( 
                    -file => [ 'local.macro', '~/.macro/global.macro' ] 
                    ) ;

    # Create a macro object and create initial macros/scripts from the
    # definition(s) given:
    my $Macro = Text::MacroScript->new(
                    -macro => [
                            [ 'MAX_INT' => '32767' ],
                        ],
                    -script => [
                        [ 'DHM2S' => 
                            [ 
                                my $s = (#0*24*60*60)+(#1*60*60)+(#2*60) ;
                                "#0 days, #1 hrs, #2 mins = $s secs" 
                            ],
                        ],
                    -variable => [ '*MARKER*' => 0 ],
                    ) ;

    # We may of course use any combination of the options. 

    my $Macro = Text::MacroScript->new( -comment => 1 ) ; # Create the %%[] macro.

    # define()

    $Macro->define( -macro, $macroname, $macrobody ) ;

    $Macro->define( -script, $scriptname, $scriptbody ) ;

    $Macro->define( -variable, $variablename, $variablebody ) ;

    # undefine()

    $Macro->undefine( -macro, $macroname ) ;

    $Macro->undefine( -script, $scriptname ) ;

    $Macro->undefine( -variable, $variablename ) ;

    # undefine_all()

    $Macro->undefine( -macro ) ;

    $Macro->undefine( -script ) ;

    $Macro->undefine( -variable ) ;

    # list()

    @macros    = $Macro->list( -macro ) ;
    @macros    = $Macro->list( -macro, -namesonly ) ;

    @scripts   = $Macro->list( -script ) ;
    @scripts   = $Macro->list( -script, -namesonly ) ;

    @variables = $Macro->list( -variable ) ;
    @variables = $Macro->list( -variable, -namesonly ) ;

    # load_file() - always treats the contents as within delimiters if we are
    # doing embedded processing.

    $Macro->load_file( $filename ) ;

    # expand_file() - calls expand_embedded() if we are doing embedded
    # processing otherwise calls expand().

    $Macro->expand_file( $filename ) ;
    @expanded = $Macro->expand_file( $filename ) ;

    
    # expand()

    $expanded = $Macro->expand( $unexpanded ) ;
    $expanded = $Macro->expand( $unexpanded, $filename ) ;

    # expand_embedded()

    $expanded = $Macro->expand_embedded( $unexpanded ) ;
    $expanded = $Macro->expand_embedded( $unexpanded, $filename ) ;


This bundle also includes the C<macro> and C<macrodir> scripts which allows us
to expand macros without having to use/understand C<Text::MacroScript.pm>,
although you will have to learn the handful of macro commands available and
which are documented here and in C<macro>. C<macro> provides more
documentation on the embedded approach.

The C<macroutil.pl> library supplied provides some functions which you may
choose to use in HTML work for example.

=head1 DESCRIPTION

Define macros, scripts and variables in macro files or directly in text files.

Commands may appear in separate macro files which are loaded in either via the
text files they process (e.g. via the C<%LOAD> command), or may be embedded
directly in text files. Almost every command that can appear in a file has an
equivalent object method so that programmers may achieve the same things in
code as can be achieved by macro commands in texts; there are also additional
methods which have no command equivalents.

Most the examples given here use the macro approach. However this module now
directly supports an embedded approach and this is now documented. Although
you may specify your own delimiters where shown in examples we use the default
delimiters of C<E<gt>:> and C<:E<lt>> throughout.

=head2 Public methods

    new         class   object
    get         class   object
    define              object
    undefine            object
    list                object
    undefine_all        object
    load_file           object
    expand_file         object
    expand              object
    expand_embedded     object


=head2 Summary of Commands

These commands may appear in separate `macro' files, and/or in the body of
files. Wherever a macroname or scriptname is encountered it will be replaced
by the body of the macro or the result of the evaluation of the script using
any parameters that are given.

Note that if we are using an embedded approach commands, macro names and
script names should appear between delimiters. (Except when we C<%LOAD> since
this assumes the whole file is `embedded'.)

    %DEFINE macroname [macro body]

    %DEFINE macroname
    multi-line
    macro body
    #0, #1 are the first and second parameters if any used
    %END_DEFINE

    %UNDEFINE macroname

    %UNDEFINE_ALL   # Undefine all macros

    %DEFINE_SCRIPT scriptname [script body]

    %DEFINE_SCRIPT scriptname
    multi-line
    script body
    arbitrary perl
    optional parameters are in @Param, although #0, etc may be used
    any variables are in %Var, although #varname may be used
    %END_DEFINE

    %UNDEFINE scriptname

    %UNDEFINE_ALL_SCRIPT

    %DEFINE_VARIABLE variablename [variable value]

    %UNDEFINE variablename

    %UNDEFINE_ALL_VARIABLE

    %LOAD[path/filename]    # Instantiate macros/scripts/variables in this
                            # file, but discard the text

    %INCLUDE[path/filename] # Instantiate macros/scripts/variables in this
                            # file and output the resultant text

    %REQUIRE[path/filename] # Make Perl require a file e.g. of functions,
                            # modules, etc. which can then be accessed within
                            # scripts. 
 
    %CASE [condition]       # Provides #ifdef-type functionality
    %END_CASE

Thus, in the body of a file we may have, for example:

    %DEFINE &B [Billericky Rickety Builders]
    Some arbitrary text.
    We are writing to complain to the &B about the shoddy work they did.

If we are taking the embedded approach the example above might become:

    <:%DEFINE BB [Billericky Rickety Builders]:>
    Some arbitrary text.
    We are writing to complain to the <:BB:> about the shoddy work they did.

When using an embedded approach we don't have to make the macro or script name
unique within the text, (although each must be distinct from each other),
since the delimiters are used to signify them. However since expansion applies
recursively it is still wise to make names distinctive.

=head2 Macro systems vs embedded systems

Macro systems read all the text, substituting anything which matches a macro
name with the macro's body (or script name with the result of the execution of
the script). This makes macro systems slower (they have to check for
macro/script names everywhere, not just in a delimited section) and more risky
(if we choose a macro/script name that normally occurs in the text we'll end
up with a mess) than embedded systems. On the other hand because they work on
the whole text not just delimited bits, macro systems can perform processing
that embedded systems can't. Macro systems are used extensively, for example
the CPP, C pre-processor, with its #DEFINE's, etc.

Essentially, embedded systems print all text until they hit an opening
delimiter. They then execute any code up until the closing delimiter. The text
that results replaces everything between and including the delimeters. They
then carry on printing text until they hit an opening delimeter and so on
until they've finished processing all the text. This module now provides both
approaches.

=head2 Creating macro objects with C<new()>

For macro processing:

    my $Macro = Text::MacroScript->new ;

For embedded macro processing:

    my $Macro = Text::MacroScript->new( -embedded => 1 ) ; 
    # Delimiters default to <: and :>

Or specify your own delimiters:
    
    my $Macro = Text::MacroScript->new( -opendelim => '[[', -closedelim => ']]' ) ;

Or specify one delimiter to use for both (probably not wise):

    my $Macro = Text::MacroScript->new( -opendelim => '%%' ) ; 
    # -closedelim defaults to -opendelim, e.g. %% in this case
 

The full list of options that may be specified at object creation:

C<-comment> optional integer; 1 = create the C<%%[]> comment macro; default 0.

C<-file> optional array reference of strings; read macros and scripts from the
file(s) given - they are C<%LOAD>ed so are treated as already embedded if we
are doing embedded processing. Default is a reference to an empty array. 

C<-macro> optional array reference of macros, in the form:

    my $Macro = Text::MacroScript->new(
                    -macro => [
                        ["name1"=>"body1"],
                        ["name2"=>"body2"],
                        ["name3"=>"body3"],
                    ],
                    ) ;

Default is a reference to an empty array. 

C<-script> optional array reference of scripts, in the form:

    my $Macro = Text::MacroScript->new(
                    -script => [
                        ["name1"=>"body1"],
                        ["name2"=>"body2"],
                        ["name3"=>"body3"],
                    ],
                    ) ;

Default is a reference to an empty array. 

C<-variable> optional array reference of variables, in the form:

    my $Macro = Text::MacroScript->new(
                    -variable => [
                        ["name1"=>"value1"],
                        ["name2"=>"value2"],
                        ["name3"=>"value3"],
                    ],
                    ) ;

Default is a reference to an empty array. 

C<-embedded> optional integer, 1 = use embedded processing; 0 = use macro
processing. Default is 0. If set to 1 then the delimiters become <: and :>
unless otherwise specified.

C<-opendelim> optional string, default is undef unless C<-embedded> is 1 in
which case default is <: if C<-opendelim> is undefined or the empty string.

C<-closedelim> optional string, default is undef unless C<-embedded> is 1 in
which case default is :> if C<-closedelim> is undefined or the empty string
and C<-opendelim> is <: or C<-opendelim> if C<-opendelim> is not <:.

=head2 Defining Macros with C<%DEFINE> and C<define()>

In files we would write:

    %DEFINE MAC [The Mackintosh Macro]

The equivalent method call is:

    $Macro->define( -macro, 'MAC', 'The Mackintosh Macro' ) ;

We can call our macro anything, excluding white-space characters and [,
although [ is not advised. So a name like C<%*&!> is fine - indeed names which
could not normally appear in the text are recommended to avoid having the
wrong thing substituted. We should also avoid calling macros, scripts or
variables names beginning with #. All names are case-sensitive.

Note that if we define a macro and then a script with the same name the
script will effectively replace the macro.

We can have parameters (for macros and scripts), e.g.:

    %DEFINE *P [The forename is #0 and the surname is #1]

Parameters used in the source text can contain square brackets since macro
will grab up to the last square bracket on the line. The only thing we can't
pass are `|'s since these are used to separate parameters. White-space between
the macro name and the [ is optional in definitions but I<not allowed> in the
source text.

Parameters are named #0, #1, etc. There is a limit of 100 parameters, i.e.
#0..#99, and we must use all those we specify. In the example above we I<must>
use *P[param1|param2], e.g. *P[Jim|Hendrix]; if we don't
C<Text::MacroScript.pm> will croak. Note that macro names and their parameters
must all be on the same line (although this is relaxed if you use paragraph
mode). 

Because we use # to signify parameters if you require text that consists of a
# followed by digits then you should escape the #, e.g.

    %DEFINE *GRAY[<font color="\#121212">#0</font>]

We can use as many I<more> parameters than we need, for example add a third to
document: *P[Jim|Hendrix|Musician] will become `The forename is Jim and the
surname is Hendrix', just as in the previous example; the third parameter,
`Musician', will simply be thrown away.

If we take an embedded approach we might write this example thus:

    <:%DEFINE P [The forename is #0 and the surname is #1]:>

and in the text, <:P[Jim|Hendrix]:> will be transformed appropriately.

If we define a macro, script or variable and later define the same name the
later definition will replace the earlier one. This is useful for making local
macro definitions over-ride global ones, simply by loading the global ones
first.

Although macros can have plain textual names like this:

    %DEFINE MAX_INT [32767]

It is generally wise to use a prefix and/or suffix to make sure we don't
expand something unintentionally, e.g.

    %DEFINE $MAX_INT [65535]

B<Macro expansion is no respector of quoted strings or anything else> - 
B<if the name matches the expansion will take place!>

Multi-line definitions are permitted (here's an example I use with the lout
typesetting language):

    %DEFINE SCENE
    @Section
        @Title {#0}
    @Begin
    @PP
    @Include {#1}
    @End @Section
    %END_DEFINE

This allows us to write the following in our lout files:

    SCENE[ The title of the scene | scene1.lt ]

which is a lot shorter than the definition.

The body of a macro may not contain a literal null. If you really need one
then use a script and represent the null as C<chr(0)>.

B<Converting a macro to a script>

This can be achieved very simply. For a one line macro simply enclose the
body between qq{ and }, e.g.

    %DEFINE $SURNAME [Baggins]

becomes

    %DEFINE_SCRIPT $SURNAME [qq{Baggins}]

For a multi-line macro use a here document, e.g.

    %DEFINE SCENE
    @Section
        @Title {#0}
    @Begin
    @PP
    @Include {#1}
    @End @Section
    %END_DEFINE

becomes

    %DEFINE_SCRIPT SCENE
    <<__EOT__
    \@Section
        \@Title {#0}
    \@Begin
    \@PP
    \@Include {#1}
    \@End \@Section
    __EOT__
    %END_DEFINE

Note that the @s had to be escaped because they have a special meaning in
perl.

=head2 Defining Scripts with C<%DEFINE_SCRIPT> and C<define()>

Instead of straight textual substitution, we can have some perl executed
(after any parameters have been replaced in the perl text):

    %DEFINE_SCRIPT *ADD ["#0 + #1 = " . (#0 + #1)]

or by using the equivalent method call:

    $Macro->define( -script, '*ADD', '"#0 + #1 = " . (#0 + #1)' ) ;

These would be used as *ADD[5|11] in the text which would be output as:

    These would be used as 5 + 11 = 16 in the text...

In script definitions we can use an alternative way of passing parameters
instead of or in addition to the #0 syntax.

This is particularly useful if we want to take a variable number of parameters
since the #0 etc syntax does not provide for this. An array called C<@Param>
is available to our perl code that has any parameters. This allows things
like the following to be achieved:

    %DEFINE_SCRIPT ^PEOPLE
    # We don't use the name hash number params but read straight from the
    # array:
    my $a = "friends and relatives are " ;
    $a .= join ", ", @Param ;
    $a ;
    %END_DEFINE

The above would expand in the following text:

    Her ^PEOPLE[Anna|John|Zebadiah].

to
    Her friends and relatives are Anna, John, Zebadiah.

In addition to having access to the parameters either using the #0 syntax or
the C<@Param> array, we can also access any variables that have been defined
using C<%DEFINE_VARIABLE> (see later). These are accessible either using
#variablename similarly to the #0 parameter syntax, or via the C<%Var> hash.
Although we can change both C<@Param> and C<%Var> elements in our script,
the changes to C<@Param> only apply within the script whereas changes to
C<%Var> apply from that point on globally.

Note that if you require a literal # followed by digits in a script body then
you must escape the # like this C<\#>.

Macro names can be any length and consist of any characters (including
non-printable which is probably only useful within code), except white-space
and [, although ] is not recommended and a leading # should be avoided.

Here's a simple date-stamp style:

    %DEFINE_SCRIPT *DATESTAMP
    {
        my( $d, $m, $y ) = (localtime( time ))[3..5] ;
        $m++ ;
        $m = "0$m" if $m < 10 ;
        $d = "0$d" if $d < 10 ;
        $y += 1900 ;
        "#0 on $y/$m/$d" ;
    }
    %END_DEFINE

If we wanted to add the above in code we'd have to make sure the $variables
weren't interpolated:

    $Macro->define( -script, '*DATESTAMP', <<'__EOT__' ) ;
    {
        my( $d, $m, $y ) = (localtime( time ))[3..5] ;
        $m++ ;
        $m = "0$m" if $m < 10 ;
        $d = "0$d" if $d < 10 ;
        $y += 1900 ;
        "#0 on $y/$m/$d" ;
    }
    __EOT__
 
Here's (a somewhat contrived example of) how the above would be used:

    <HTML>
    <HEAD><TITLE>Test Page</TITLE></HEAD>
    <BODY>
    *DATESTAMP[Last Updated]<P>
    This page is up-to-date and will remain valid until *DATESTAMP[midnight]
    </BODY>
    </HTML>

Thus we could have a file, C<test.html.m> containing:

    %DEFINE_SCRIPT *DATESTAMP
    {
        my( $d, $m, $y ) = (localtime( time ))[3..5] ;
        $m++ ;
        $m = "0$m" if $m < 10 ;
        $d = "0$d" if $d < 10 ;
        $y += 1900 ;
        "#0 on $y/$m/$d" ;
    }
    %END_DEFINE
    <HTML>
    <HEAD><TITLE>Test Page</TITLE></HEAD>
    <BODY>
    *DATESTAMP[Last Updated]<P>
    This page is up-to-date and will remain valid until *DATESTAMP[midnight]
    </BODY>
    </HTML>

which when expanded, either in code using C<$Macro-E<gt>expand()>, or using the
simple C<macro> utility supplied with C<Text::MacroScript.pm>:

    [1]% macro test.html.m > test.html

C<test.html> will contain just this:

    <HTML>
    <HEAD><TITLE>Test Page</TITLE></HEAD>
    <BODY>
    Last Updated on 1999/08/21<P>
    This page is up-to-date and will remain valid until midnight on 1999/08/21
    </BODY>
    </HTML>

Of course in practice we wouldn't want to define everything in-line like this.
See C<%LOAD> later for an alternative.

This example written in embedded style might be written thus:

    <:
    %DEFINE_SCRIPT DATESTAMP
    {
        my( $d, $m, $y ) = (localtime( time ))[3..5] ;
        $m++ ;
        $m = "0$m" if $m < 10 ;
        $d = "0$d" if $d < 10 ;
        $y += 1900 ;
        "#0 on $y/$m/$d" ;
    }
    %END_DEFINE
    :>
    <HTML>
    <HEAD><TITLE>Test Page</TITLE></HEAD>
    <BODY>
    <!-- Note how the parameter must be within the delimiters. -->
    <:DATESTAMP[Last Updated]:><P>
    This page is up-to-date and will remain valid until <:DATESTAMP[midnight]:>
    </BODY>
    </HTML>

For more (and better) HTML examples see the example file C<html.macro>.

The body of a script may not contain a literal null. If you really need one
then represent the null as C<chr(0)>.

=head2 Defining Variables with C<%DEFINE_VARIABLE> and C<define()>

We can also define variables:

    %DEFINE_VARIABLE &*! [89.1232]

or in code:

    $Macro->define( -variable, '&*!', 89.1232 ) ;

Note that there is no multi-line version of C<%DEFINE_VARIABLE>.

All current variables are available inside C<%DEFINE_SCRIPT> scripts in the C<%Var>
hash:

    %DEFINE_SCRIPT *TEST1
    $a = '' ;
    while( my( $key, $val ) each( %Var ) ) {
        $a .= "$key = $val\n" ;
    }
    $a ;
    %END_DEFINE

Here's another example:
    
    %DEFINE_VARIABLE XCOORD[256]
    %DEFINE_VARIABLE YCOORD[112]
        :
    The X coord is *SCALE[X|16] and the Y coord is *SCALE[Y|16] 
    
    %DEFINE_SCRIPT *SCALE
    my $coord = shift @Param ;
    my $scale = shift @Param ;
    my $val   = $Var{$coord} ;
    $val %= scale ; # Scale it
    $val ; 
    %END_DEFINE
        
Variables may be modified within script C<%DEFINE>s, e.g.

    %DEFINE_VARIABLE VV[Foxtrot]
    # VV eq 'Foxtrot'
    # other text
    # Here we use the #variable synax:
    %DEFINE_SCRIPT VV[#VV='Alpha']
    # VV eq 'Alpha' - note that we *must* refer to the script (as we've done
    # on the line following) for it to execute.
    # other text
    # Here we use perl syntax:
    %DEFINE_SCRIPT VV[$Var{'VV'}='Tango']
    # VV eq 'Tango' - note that we *must* refer to the script (as we've done
    # on the line following) for it to execute.

As we can see variables support the #variable syntax similarly to parameters
which support #0 etc and ara available in scripts via the C<@Param> array.
Note that changing parameters within a script only apply within the script;
whereas changing variables in the C<%Var> hash in a script changes them from
that point on globally.

Variables are also used with C<%CASE> (covered later).

=head2 Loading and including files with C<%LOAD> and C<load_file()>, and C<%INCLUDE> and C<expand_file()>

Although we can define macros directly in the files that require them it is often
more useful to define them separately and include them in all those that need
them.

One way of achieving this is to load in the macros/scripts first and then
process the file(s). In code this would be achieved like this:

    $Macro->load_file( $macro_file ) ; # Loads definitions only, ignores any
                                       # other text. If working in embedded
                                       # mode the file is treated as if
                                       # wrapped in delimiters.
    $Macro->expand_file( $file ) ;     # Expands definitions (and instantiates
                                       # any definitions that appear in the
                                       # file); output is to the current
                                       # output filehandle.
    my @expanded = $Macro->expand_file( $file ) ; # Output to array.

From the command line it would be achieved thus:

    [2]% macro -f ~/.macro/html.macros test.html.m > test.html
    

One disadvantage of this approach, especially if we have lots of macro files,
is that we can easily forget which macro files are required by which text
files. One solution to this is to go back to C<%DEFINE>ing in the text files
themselves, but this would lose reusability. The answer to both these problems
is to use the C<%LOAD> command which loads the definitions from the named file at
the point it appears in the text file:

    %LOAD[~/.macro/html.macros]
    <HTML>
    <HEAD><TITLE>Test Page Again</TITLE></HEAD>
    <BODY>
    *DATESTAMP[Last Updated]<P>
    This page will remain valid until *DATESTAMP[midnight]
    </BODY>
    </HTML>

The above text has the same output but we don't have to remember or explicitly
load the macros. In code we can simply do this:

    my @expanded = $Macro->expand_file( $file ) ;

or from the command line:

    [3]% macro test.html.m > test.html

    
At the beginning of our lout typesetting files we might put this line:

    %LOAD[local.macros]

The first line of the C<local.macros> file is:

    %LOAD[~/.macro/lout.macros]

So this loads both global macros then local ones (which if they have the same
name will of course over-ride).

This saves repeating the C<%DEFINE> definitions in all the files and makes
maintenance easier.

C<%LOAD> loads perl scripts and macros, but ignores any other text. Thus we can
use C<%LOAD>, or its method equivalent C<load_file()>, on I<any> file, and it
will only ever instantiate macros and scripts and produce no output. When we
are using embedded processing any file C<%LOAD>ed is treated as if wrapped in
delimiters.

If we want to include the entire contents of another file, and perform macro
expansion on that file then use C<%INCLUDE>, e.g.

    %INCLUDE[/path/to/file/with/scripts-and-macros-and-text]

The C<%INCLUDE> command will instantiate any macros and scripts it encounters
and include all other lines of text (with macro/script expansion) in the
output stream.

Macros and scripts are expanded in the following order:
1. scripts (longest named first, shortest named last)
2. macros  (longest named first, shortest named last)

=head2 Requiring files using C<%REQUIRE>

We often want our scripts to have access to a bundle of functions that we have
created or that are in other modules. This can now be achieved by:

    %REQUIRE[/path/to/mylibrary.pl]

An example library C<macroutil.pl> is provided with examples of usage in
C<html.macro>.

There is no equivalent object method because if we're writing code we can
`use' or `require' as needed and if we're writing macros then we use
C<%REQUIRE>.

=head2 Skipping text using C<%CASE> and C<%END_CASE> 

It is possible to selectively skip parts of the text.

    %CASE[0]
    All the text here will be discarded.
    No matter how much there is.
    This is effectively a `comment' case.
    %END_CASE

The above is useful for multi-line comments.

We can also skip selectively. Here's an if...then:

    %CASE[#OS eq 'Linux']
    Skipped if the condition is FALSE. 
    %END_CASE

The condition can be any perl fragment. We can use previously defined
variables either using the #variable syntax as shown above or using the
exported perl name, thus in this case either C<#OS>, or C<%Var{'OS'}>
whichever we prefer.

If the condition is true the text is output with macro/script expansion as
normal; if the condition is false the text is skipped.

The if...then...else structure:

    %DEFINE_VARIABLE OS[Linux]

    %CASE[$Var{'OS'} eq 'Linux']
    Linux specific stuff.
    %CASE[#OS ne 'Linux']
    Non-linux stuff - note that both references to the OS variable are
    identical in the expression (#OS is converted internally to $Var{'0S'} so
    the eval sees the same code in both cases
    %END_CASE

Although nested C<%CASE>s are not supported we can get the same functionality
(and indeed more versatility because we can use full perl expressions), e.g.:

    %DEFINE_VARIABLE TARGET[Linux]

    %CASE[#TARGET eq 'Win32' or #TARGET eq 'DOS']
    Win32/DOS stuff.
    %CASE[#TARGET eq 'Win32']
    Win32 only stuff.
    %CASE[#TARGET eq 'DOS']
    DOS only stuff.
    %CASE[#TARGET eq 'Win32' or #TARGET eq 'DOS']
    More Win32/DOS stuff.
    %END_CASE

Although C<macro> doesn't support nested C<%CASE>'s we can still represent
logic like this:

    if cond1 then
        if cond2
            do cond1 + cond2 stuff
        else
            do cond1 stuff
        end if
    else
        do other stuff
    end if

By `unrolling' the expression and writing something like this:

    %CASE[#cond1 and #cond2]
        do cond1 + cond2 stuff
    %CASE[#cond1 and (not #cond2)]
        do cond1 stuff
    %CASE[(not #cond1) and (not #cond2)]
        do other stuff
    %END_CASE

In other words we must fully specify the conditions for each case.

We can use any other macro/script command within C<%CASE> commands, e.g.
C<%DEFINE>s, etc., as well as have any text that will be macro/script expanded
as normal.

=head2 Undefining with C<%UNDEFINE> and C<undefine()>

Macros and scripts may be undefined in files:

    %UNDEFINE *P
    %UNDEFINE_SCRIPT *DATESTAMP
    %UNDEFINE_VARIABLE &*!

and in code:

    $Macro->undefine( -macro, '*P' ) ; 
    $Macro->undefine( -script, '*DATESTAMP' ) ; 
    $Macro->undefine( -variable, '&*!' ) ; 

All macros, scripts and variables can be undefined:

    %UNDEFINE_ALL
    %UNDEFINE_ALL_SCRIPT
    %UNDEFINE_ALL_VARIABLE

    $Macro->undefine_all( -macro ) ;
    $Macro->undefine_all( -script ) ;
    $Macro->undefine_all( -variable ) ;

One use of undefining everything is to ensure we get a clean start. We might
head up our files thus:

    %UNDEFINE_ALL
    %UNDEFINE_ALL_SCRIPT
    %UNDEFINE_ALL_VARIABLE
    %LOAD[mymacros]
    text goes here

=head2 Listing macros, scripts and variables with C<list()>

We can list the macros, scripts and variables in code with list:

    $Macro->list( -macro ) ;

This will print the macros currently defined to the current file handle - if
there is one. If used in an array context will provide the list one macro per
array element:

    @macros = $Macro->list( -macro ) ;

    # Just give us the macro names:
    @macros = $Macro->list( -macro, -nameonly ) ;

There are equivalents for scripts and variables:

    @scripts   = $Macro->list( -script ) ;
    @variables = $Macro->list( -variable ) ;

=head2 Commenting

Generally the text files that we process are in formats that support
commenting, e.g. HTML:

    <!-- This is an HTML comment -->

Sometimes however we want to put comments in our macro source files that won't
end up in the output files. One simple way of achieving this is to define a
macro whose body is empty; when its called with any number of parameters (our
comments), their text is thrown away:

    %DEFINE %%[]

which is used like this in texts:

    The comment comes %%[Here | [anything] put here will disappear]here!

The output of the above will be:

    The comment comes here!

We can add the definition in code:

    $Macro->define( -macro, '%%', '' ) ;

Or the macro can be added automatically for us when we create the Macro
object:

    my $Macro = Text::MacroScript->new( -comment => 1 ) ; 
    # All other options may be used too of course.

However the easiest way to comment is to use C<%CASE>:

    %CASE[0]
    This unconditionally skips text up until the end marker since the
    condition is always false.
    %END_CASE

=head1 IMPORTABLE FUNCTIONS

In version 1.25 I introduced some useful importable functions. These have now
been removed from the module. Instead I supply a perl library C<macroutil.pl>
which has these functions (abspath, relpath, today) since Text::MacroScript
can now `require' in any library file you like using the C<%REQUIRE>
directive.

=head1 EXAMPLES

I now include a sample C<html.macro> file for use with HTML documents. It uses
the C<macrodir> program (supplied). The macro examples include macros which
use C<relpath> and also two macros which will include `new' and `updated'
images up until a specified expiry date using variables.

(Also see DESCRIPTION.)

=head1 BUGS

Lousy error reporting for embedded perl in most cases.

=head1 AUTHOR

Mark Summerfield. I can be contacted as <summer@perlpress.com> -
please include the word 'macroscript' in the subject line.

=head1 COPYRIGHT

Copyright (c) Mark Summerfield 1999-2000. All Rights Reserved.

This module may be used/distributed/modified under the LGPL. 

=cut
