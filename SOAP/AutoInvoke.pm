package SOAP::AutoInvoke;


BEGIN
{

use strict;
use vars qw ( $VERSION $AUTOLOAD $DEFAULT_HOST $DEFAULT_PORT $DEFAULT_ENDPOINT $DEFAULT_METHOD_URI  );

$VERSION = '0.20';

require 5.000;

use SOAP::EnvelopeMaker;
use SOAP::Struct;
use SOAP::Transport::HTTP::Client;
use SOAP::Parser;
use Data::Dumper;

$DEFAULT_HOST       = "localhost";
$DEFAULT_PORT       = 80;
$DEFAULT_ENDPOINT   = "/soap?class=";
$DEFAULT_METHOD_URI = "urn:com-name-your";

}



sub new
{
my $class = shift;
my $self  = {};

	my $blessing = bless ( $self, $class );

	$self->{_soap_host}       = $DEFAULT_HOST;
	$self->{_soap_port}       = $DEFAULT_PORT;
	$self->{_soap_endpoint}   = $DEFAULT_ENDPOINT.$class;
	$self->{_soap_method_uri} = $DEFAULT_METHOD_URI;
	$self->{_soap_new_method} = "new";
	$self->{_soap_new_args}   = ();

	#
	# override defaults if arguments passed.
	#
	if (@_) {
		while ( my $arg = shift ) {
			if ( $arg eq "_soap_host"
				 || $arg eq "_soap_port"
				 || $arg eq "_soap_endpoint"
				 || $arg eq "_soap_method_uri"
				 || $arg eq "_soap_new_method" )
			{
				$self->{$arg} = shift;
			}
			else {
				push ( @{$self->{_soap_new_args}}, $arg );
			}
		}
	}

	$blessing;
}



sub setHost
{
	$_[0]->{_soap_host} = $_[1];
}



sub setPort
{
	$_[0]->{_soap_port} = $_[1];
}



sub setEndPoint
{
	$_[0]->{_soap_endpoint} .= $_[1];
}



sub setMethodURI
{
	$_[0]->{_soap_method_uri} .= $_[1];
}



sub setNewMethod
{
	$_[0]->{_soap_new_method} .= $_[1];
}



sub getHost
{
	$_[0]->{_soap_gethost};
}



sub getPort
{
	$_[0]->{_soap_getport};
}



sub getEndPoint
{
	$_[0]->{_soap_endpoint};
}



sub getMethodURI
{
	$_[0]->{_soap_method_uri};
}



sub getNewMethod
{
	$_[0]->{_soap_new_method};
}



sub getNewArgs
{
	(wantarray)
	  ?  @{$self->{_soap_new_args}}
      :  $self->{_soap_new_args}
	;
}



sub setNewArgs
{
	$self->{_soap_new_args} = ();

	if (@_) {
		while ( my $arg = shift ) {
				push ( @{$self->{_soap_new_args}}, $arg );
		}
	}
}



sub deliverRequest
{
my ($self, $method_name) = (shift, shift);

	#
	# Convert any arguments into a hash for send SOAP::Struct.
	#
	my %ARGV;
	my $arg = 0;

	foreach (@_) {
		if ( ref ($_) eq "ARRAY" ) {
			$_ = Dumper ( $_ );
			s/^\$VAR1 = /array::/g;
		}
		$ARGV{"ARG$arg"} = $_;
		$arg++;	
	}
	$arg = 0;
	if ( $self->{_soap_new_args} ) {
		foreach (@{$self->{_soap_new_args}}) {
			if ( ref ($_) eq "ARRAY" ) {
				$_ = Dumper ( $_ );
				s/^\$VAR1 = /array::/g;
			}
			$ARGV{"NewARG$arg"} = $_;
			$arg++;	
		}
	}

	#
	# For some reason I feel compelled to do this..
	#
	$ARGV{ARGC}              = scalar @_;

	$ARGV{_is_soap_autoload} = 1;
	$ARGV{_soap_new_method}  = ( $self->{_soap_new_method} )
	                         ?   $self->{_soap_new_method}
	                         :  ''
	                         ;


	#
	# Now set and send our request to the server.
	#
	my $soap_request = '';
	my $output_fcn = sub { $soap_request .= shift; };
	my $em = SOAP::EnvelopeMaker->new ( $output_fcn );

	my $body = SOAP::Struct->new (
	           %ARGV
	);

	$em->set_body( $self->{method_uri}, $method_name, 0, $body );


	my $soap_on_http = SOAP::Transport::HTTP::Client->new();

	my $soap_response = $soap_on_http->send_receive (
                        $self->{_soap_host},
                        $self->{_soap_port},
                        $self->{_soap_endpoint},
                        $self->{_soap_method_uri},
                        $method_name,
                        $soap_request
	);

	my $soap_parser = SOAP::Parser->new();

	$soap_parser->parsestring($soap_response);

	$body = $soap_parser->get_body;

	#
	# Convert any return arguments into a return list. 
	#
	$arg = 0;
	@_ = ();
	while ( $_ = $body->{"ARG$arg"} ) {
		if ( /^array::/ ) {
			s/^array:://;
			$_ = eval ( $_ );
		}
		push ( @_, $_ );
		$arg++;
	}

	@_;
}



DESTROY
{
 	$_[0] = undef;
}



sub AUTOLOAD
{
        my($self) = shift;
        my($method) = ($AUTOLOAD =~ /::([^:]+)$/);
        return unless ($method);

        $self->deliverRequest ( $method, @_ );
}



1;
__END__


=head1 NAME

SOAP::AutoInvoke - Automarshall methods for Perl SOAP

=head1 SYNOPSIS

 #!/usr/bin/perl -w

 #
 #  Client example that goes with server example
 #  in SOAP::Transport::HTTP::AutoInvoke
 #
 use strict;

 package Calculator;
 use base qw( SOAP::AutoInvoke );


 package main;

 my $calc = new Calculator;


 print "sum = ", $calc->add ( 1, 2, 3 ), "\n";


=head1 DESCRIPTION

The intention of SOAP::AutoInvoke is to allow a SOAP client to use a remote
class as if it were local.  The remote package is treated as local with
a declaration like:

  package MyClass;
  use base qw( SOAP::AutoInvoke );

The SOAP::AutoInvoke base class will "Autoload" methods called from an
instance of "MyClass", send it to the server side, and return the results
to the caller's space. 

=head2 Provided Methods


=item B<new>:

I< >
The 'new' method may be called with option arguments to reset variables
from the defaults.

  my $class = new MyClass (
                  _soap_host       => 'anywhere.com',
                  _soap_port       => 80,
                  _soap_endpoint   => 'soapx?class=OtherClass',
                  _soap_method_uri => 'urn:com-name-your'
              );

It is advisable to set the package defaults at installation time in the
SOAP/AutoInvoke.pm (this) file.  The variables may also be reset after
instantiation with the 'set' methods.

The '_soap_' variable is relevant only to the local instantiation of "MyClass".
The remote instantiation will call "new" with any arguments you have passed to
the local instantiation that did I<not> begin with '_soap_':

  my $class = new MyClass (
                  _soap_host => 'anywhere.com',
                  arg1,
                  arg2,
                  @arg3,
                  arg4   => $value,
                  :
              );

This works so long as the data types being passed are something the SOAP
package can serialize.  SOAP::AutoInvoke can send and receive simple
arrays.

To reset the name of the "new" to be called remotely:

  my $class = new MyClass (
                  :
                  _soap_new_method => 'create',
                  :
              );

To not call any new method remotely:

  my $class = new MyClass (
                  :
                  _soap_new_method => undef,
                  :
              );

=over 4

=item B<getHost>:

returns the contents of $class->{_soap_host}.

=item B<setHost>:

sets the contents of $class->{_soap_host}.

=item B<getPort>:

returns the contents of $class->{_soap_port}.

=item B<setPort>:

sets the contents of $class->{_soap_port}.

=item B<getEndPoint>:

returns the contents of $class->{_soap_endpoint}.

=item B<setEndPoint>:

sets the contents of $class->{_soap_endpoint}.

=item B<getMethodURI>:

returns the contents of $class->{_soap_method_uri}.

=item B<setMethodURI>:

sets the contents of $class->{_soap_method_uri}.

=item B<getNewArgs>:

returns the contents of $class->{_soap_new_args}.

=item B<setNewArgs>:

sets the contents of $class->{_soap_new_args}.

=item B<getNewMethod>:

returns the contents of $class->{_soap_new_method}.

=item B<setNewMethod>:

sets the contents of $class->{_soap_new_method}.  The default is "new".

=back

=head1 DEPENDENCIES

SOAP-0.28
Data::Dumper

=head1 AUTHOR

Daniel Yacob, L<yacob@rcn.com|mailto:yacob@rcn.com>

=head1 SEE ALSO

S<perl(1). SOAP(3). SOAP::Transport::HTTP::AutoInvoke(3).>
