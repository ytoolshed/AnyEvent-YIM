package AnyEvent::YIM;

# Copyright (c) 2010, Yahoo! Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Digest::MD5 qw(md5_base64);
use Log::Log4perl qw(:easy);
use URI::Escape qw(uri_escape);

use warnings;
use strict;

use base qw(Object::Event);

use AnyEvent::YIM::Util qw(create_message
                           parse_message
                           https_get
                          );

use AnyEvent::YIM::Constants qw(MSGR_DEFAULT_HOST
                                MSGR_DEFAULT_PORT
                                LOGIN_DEFAULT_HOST
                                YMSG_FIELD_USER_NAME
                                YMSG_FIELD_USER_ID
                                YMSG_FIELD_CURRENT_ID
                                YMSG_FIELD_ACTIVE_ID
                                YMSG_FIELD_SENDER
                                YMSG_FIELD_TARGET_USER
                                YMSG_FIELD_BUDDY
                                YMSG_FIELD_AWAY_STATUS
                                YMSG_FIELD_AWAY_MESSAGE
                                YMSG_FIELD_CUSTOM_DND_STATUS
                                YMSG_FIELD_UTF8_FLAG
                                YMSG_FIELD_MSG
                                YMSG_FIELD_TIME
                                YMSG_FIELD_HASH
                                YMSG_FIELD_CHALLENGE
                                YMSG_FIELD_LOGIN_Y_COOKIE
                                YMSG_FIELD_LOGIN_T_COOKIE
                                YMSG_FIELD_START_OF_RECORD
                                YMSG_FIELD_END_OF_RECORD
                                YMSG_FIELD_START_OF_LIST
                                YMSG_FIELD_END_OF_LIST
                                YMSG_FIELD_CRUMB_HASH
                                YMSG_FIELD_CAP_MATRIX
                                YMSG_HELO
                                YMSG_CAP_MATRIX
                                YMSG_USER_LOGIN_2
                                YMSG_USER_HAS_MSG
                               );

=head1 NAME

AnyEvent::YIM - AnyEvent implementation of the Yahoo! Instant Messenger protocol

=head1 VERSION

Version 0.0.2

=cut

our $VERSION = '0.0.2';

=head1 SYNOPSIS

  use AnyEvent;
  use AnyEvent::YIM;

  # create an instance
  my $yim = AnyEvent::YIM->new(
    username => $username,
    password => $password
    on_msg => \&handle_msg
  );

  # start the event loop and connect
  $yim->start();

  # handle a message
  sub handle_msg
  {
    my ($yim, $ctx) = @_;
    printf "%s: %s\n", $ctx->{sender}, $ctx->{msg};
    if ($ctx->{msg} =~ m/ping/) { $yim->msg($ctx->{sender}, "pong"); }
  }

=head1 DESCRIPTION

The L<AnyEvent::YIM> module is a very basic implementation of the Yahoo! Instant Messenger protocol which appears to be at verison 16 at this time. Because this is not an open protocol this module is the result of trial and error and probably contains many, many omissions.

Each Y!IM packet can contain multiple fields identified by unique IDs. This module processes these packets by registering callbacks for each field and constructing a context hash. This context is then flushed when certain fields, or the end of the packet, is reached. You can register an interest in either the individual fields or certain named events which at this time are: "connect", "disconnect", "msg" and "buddy".

=head1 CONSTRUCTOR

=over

=item $yim = AnyEvent::YIM->new(%args);

Creates a new AnyEvent::YIM instance. Accepts the following arguments:

=over

=item * username

The Y!IM username to use, this field is required.

=item * password

The Y!IM password to use, this field is required.

=item * msgr_host

The Y!IM host to use, defaults to AnyEvent::YIM::Constants::MSGR_DEFAULTHOST.

=item * msgr_port

The Y!IM port to use, defaults to AnyEvent::YIM::Constants::MSGR_DEFAULT_PORT.

=item * login_host

The Y!IM login host to use, defaults to AnyEvent::YIM::Constants::LOGIN_DEFAULT_HOST.

=item * debug

Set this to 1 to increase the Log4perl log level to $DEBUG.

=item * on_connect, on_disconnect, on_msg, on_buddy

Register a callback for a named event, the value should be a code ref that is executed when that event is fired. For example: on_connect => sub { ... } is the same as $yim->reg_cb( "connect", sub { ... } )

=back

=back

=cut

sub new
{
  my ($class, %args) = @_;

  my %defaults = (
    username    => undef,
    password    => undef,
    msgr_host   => MSGR_DEFAULT_HOST(),
    msgr_port   => MSGR_DEFAULT_PORT(),
    login_host  => LOGIN_DEFAULT_HOST(),
    debug       => 0,
  );

  my %static = (
    _sock       => undef,
    _quit       => undef,
    _context    => {},
    _queue      => [],
    sessionid   => 0,
    challenge   => undef,
    crumb       => undef,
    y_cookie    => undef,
    t_cookie    => undef,
    logged_in   => 0,
    logging_in  => 0
  );

  my $self = {
    %defaults,
    %args,
    %static
  };

  Log::Log4perl->easy_init(
    $self->{debug} ? $DEBUG : $INFO
  );

  LOGDIE "No username configured" unless defined $self->{username};
  LOGDIE "No password configured" unless defined $self->{password};

  bless $self, $class;

  $self->init();

  return $self;
}

sub init
{
  my ($self) = @_;

  # register the "on_*" callbacks
  foreach my $key (keys %$self)
  {
    if ($key =~ m/^on_(.+)$/)
    {
      my $event = $1;
      my $cb    = delete $self->{$key};
      $self->reg_cb($event => $cb);
    }
  }

  # challenge received from the server, do the authentication dance
  $self->reg_cb( YMSG_FIELD_CHALLENGE() => sub {
    my ($yim, $value) = @_;
    $yim->{challenge} = $value;
    DEBUG "challenge received: $value";

    my $uri = sprintf '/config/pwtoken_get?src=ymsgr&login=%s&passwd=%s',
      uri_escape( $yim->{username} ),
      uri_escape( $yim->{password} );

    https_get $yim->{login_host}, $uri, sub {
      my ($response, $header, $body) = @_;

      my @tmp = split /\r?\n/, $body;
      @tmp = split /=/, $tmp[1];
      my $token = $tmp[1];
      unless ($token)
      {
        return $yim->reconnect( 'Unable to retrieve token' );
      }

      $uri = sprintf '/config/pwtoken_login?src=ymsgr&token=%s',
        uri_escape( $token );

      https_get $yim->{login_host}, $uri, sub {
        my ($response, $header, $body) = @_;

        my ($crumb)     = $body =~ m/.*crumb=(\S+).*?/;
        my ($Y_cookie)  = $body =~ m/.*Y=(.*?\.com).*?/;
        my ($T_cookie)  = $body =~ m/.*T=(.*?\.com).*?/;

        return $yim->reconnect( 'Unable to determine crumb' )     unless $crumb;
        return $yim->reconnect( 'Unable to determine Y cookie' )  unless $Y_cookie;
        return $yim->reconnect( 'Unable to determine T cookie' )  unless $T_cookie;

        $yim->{y_cookie}  = $Y_cookie;
        $yim->{t_cookie}  = $T_cookie;

        my $crumb_challenge = $crumb . $yim->{challenge};
        $yim->{crumb}       = md5_base64( $crumb_challenge ) . '--';

        DEBUG "sessionid: " . $yim->{sessionid} . ", challenge: " . $yim->{challenge};

        my %login_msg = (
          YMSG_FIELD_USER_NAME()      => $yim->{username},
          YMSG_FIELD_CURRENT_ID()     => $yim->{username},
          YMSG_FIELD_ACTIVE_ID()      => $yim->{username},
          YMSG_FIELD_CAP_MATRIX()     => YMSG_CAP_MATRIX(),
          YMSG_FIELD_LOGIN_Y_COOKIE() => $yim->{y_cookie},
          YMSG_FIELD_LOGIN_T_COOKIE() => $yim->{t_cookie},
          YMSG_FIELD_CRUMB_HASH()     => $yim->{crumb}
        );

        $yim->send_data( create_message( \%login_msg, $yim->{sessionid}, YMSG_USER_LOGIN_2() ) );
      };
    };
  } );

  # userid is us
  $self->reg_cb( YMSG_FIELD_USER_ID() => sub {
    my ($yim, $value) = @_;
    DEBUG "userid received: $value";
    $yim->{_context}->{userid} = $value;
    unless ($yim->{logged_in})
    {
      # hooray we're logged in
      $yim->{logging_in}  = 0;
      $yim->{logged_in}   = 1;
      $yim->queue( sub {
        my ($yim, $ctx) = @_;
        $yim->event( 'connect' => $ctx );
      } );
    }
  } );

  # sender of a message
  $self->reg_cb( YMSG_FIELD_SENDER() => sub {
    my ($yim, $value) = @_;
    DEBUG "sender received: $value";
    $yim->{_context}->{sender} = $value;
  } );

  # target user of a message, this should be us
  $self->reg_cb( YMSG_FIELD_TARGET_USER() => sub {
    my ($yim, $value) = @_;
    DEBUG "target_user received: $value";
    $yim->{_context}->{target_user} = $value;
  } );

  # message!!
  $self->reg_cb( YMSG_FIELD_MSG() => sub {
    my ($yim, $value) = @_;
    DEBUG "msg received: $value";
    $yim->{_context}->{msg} = $value;
    $yim->queue( sub {
      my ($yim, $ctx) = @_;
      $yim->event( 'msg' => $ctx );
    } );
  } );

  # time of message
  $self->reg_cb( YMSG_FIELD_TIME() => sub {
    my ($yim, $value) = @_;
    DEBUG "ts received: $value";
    $yim->{_context}->{ts} = $value;
    $yim->flush_queue();
  } );

  # some hash, appears to show up at the end of a message packet
  $self->reg_cb( YMSG_FIELD_HASH() => sub {
    my ($yim, $value) = @_;
    DEBUG "hash received: $value";
    $yim->flush_queue();
  } );

  # start of record received, flush context
  $self->reg_cb( YMSG_FIELD_START_OF_RECORD() => sub {
    my ($yim, $value) = @_;
    DEBUG "start of record received";
    $yim->flush_queue();
  } );

  # end of record received, flush context
  $self->reg_cb( YMSG_FIELD_END_OF_RECORD() => sub {
    my ($yim, $value) = @_;
    DEBUG "end of record received";
    $yim->flush_queue();
  } );

  # buddy received
  $self->reg_cb( YMSG_FIELD_BUDDY() => sub {
    my ($yim, $value) = @_;
    DEBUG "buddy received: $value";
    $yim->{_context}->{buddy} = $value;
    $yim->queue( sub {
      my ($yim, $ctx) = @_;
      $yim->event( 'buddy' => $ctx );
    } );
  } );

  # away status code
  $self->reg_cb( YMSG_FIELD_AWAY_STATUS() => sub {
    my ($yim, $value) = @_;
    DEBUG "away_status received: $value";
    $yim->{_context}->{away_status} = $value;
  } );

  # away status message
  $self->reg_cb( YMSG_FIELD_AWAY_MESSAGE() => sub {
    my ($yim, $value) = @_;
    DEBUG "away_message received: $value";
    $yim->{_context}->{away_message} = $value;
  } );

  # custom dnd status
  $self->reg_cb( YMSG_FIELD_CUSTOM_DND_STATUS() => sub {
    my ($yim, $value) = @_;
    DEBUG "custom_status received: $value";
    $yim->{_context}->{custom_status} = $value;
  } );

  # utf8 flag
  $self->reg_cb( YMSG_FIELD_UTF8_FLAG() => sub {
    my ($yim, $value) = @_;
    DEBUG "utf8 flag received: $value";
    $yim->{_context}->{is_utf8} = $value;
  } );
}

=head1 METHODS

=over

=item $yim->reg_cb($event, $cb);

Register an interest in an event. The event can be either a Y!IM packet field ID or a named event such as "connect" or "msg". The callback must be a code ref. When the callback is executed, the first argument passed will always be the L<AnyEvent::YIM> object. In the case of the individual fields, the second argument will be the value for that field. In the case of named events, the second argument will be the context hash. For example:

  # field 19 is an away message, but this isn't very useful
  $yim->reg_cb(19 => sub {
    my ($yim, $value) = @_;
    print "Away message: $value\n";
  });

  # in the context of a buddy event
  $yim->reg_cb('buddy' => sub {
    my ($yim, $ctx) = @_;
    printf "%s is away: %s\n", $ctx->{buddy}, $ctx->{away_message} if $ctx->{away_message};
  });

=back

=over

=item $yim->start;

Starts the event loop and connects.

=back

=cut

sub start
{
  my ($self) = @_;

  $self->{_quit} = AnyEvent->condvar;
  $self->connect();
  $self->{_quit}->recv;
}

=over

=item $yim->connect;

Connects to Y!IM and begins the authentication process. If any portion of authentication fails it will automatically reconnect. Once the user is authenticated the "connect" event will be fired.

=back

=cut

sub connect
{
  my ($self) = @_;

  return 1 if $self->{_sock};

  tcp_connect $self->{msgr_host}, $self->{msgr_port}, sub {
    my ($fh, $peerhost, $peerport) = @_;

    LOGDIE "Couldn't create socket" unless $fh;

    $self->{_sock} = AnyEvent::Handle->new(
      fh        => $fh,
      autocork  => 1,
      on_eof    => sub {
        $self->disconnect( "EOF: $!" );
      },
      on_error  => sub {
        $self->disconnect( "ERROR: $!" );
      },
      on_read   => sub {
        my ($handle) = @_;
        my $data = $handle->rbuf;
        if (length($data) >= 20)
        {
          # parse the message header
          my ($head,$version,$vendor,$length,$cmd,$status,$sid) = unpack('a4nnnnNN',substr($data,0,20));
          # if we have enough data, extract the message and return the rest to the rbuf
          if (length($data) >= 20+$length)
          {
            my $message = substr($data,0,20+$length,'');
            $handle->rbuf = $data;
            $self->handle_data($message);
          }
        }
      }
    );

    # we are logging in!
    $self->{logging_in} = 1;
    # send the login message
    $self->send_data(create_message({ YMSG_FIELD_CURRENT_ID() => $self->{username}}, 0, YMSG_HELO()));
  };
}

=over

=item $yim->disconnect($reason);

Disconnects from Y!IM. The disconnect reason is optional. This will fire the "disconnect" event with the supplied reason or the default reason of "No reason".

=back

=cut

sub disconnect
{
  my ($self, $msg) = @_;
  $msg ||= "No reason";

  foreach my $field (qw(_sock challenge sessionid crumb y_cookie t_cookie))
  {
    undef $self->{$field};
  }
  $self->{logged_in}  = 0;
  $self->{logging_in} = 0;

  DEBUG "Disconnected: $msg";

  $self->event( 'disconnect' => $msg );
}

sub reconnect
{
  my ($self, $msg) = @_;

  $self->disconnect($msg);
  $self->connect();
}

=over

=item $yim->quit;

Stops the event loop, but does not disconnect.

=back

=cut

sub quit
{
  my ($self, $msg) = @_;
  WARN $msg if $msg;
  $self->{_quit}->send;
}

sub handle_data
{
  my ($self, $data) = @_;

  return unless $data;

  my $message = parse_message($data);

  $self->{sessionid} = $message->{header}->{sid} unless $self->{sessionid};

  while (@{$message->{body}})
  {
    my $code  = shift @{$message->{body}};
    my $value = shift @{$message->{body}};
    DEBUG sprintf "%s: %s\n", ( $code || '' ), ( $value || '' );
    $self->event( $code => $value );
  }

  $self->flush_queue();
}

sub send_data
{
  my ($self, $message) = @_;

  return unless $message;
  return unless $self->{_sock};

  DEBUG "sending: $message";

  syswrite $self->{_sock}->{fh}, $message, length($message);
}

=over

=item $yim->queue($cb);

Queue a callback to be executed the next time the context if flushed. This will happen when either the end of a packet is reached, or a field within a packet is reached that L<AnyEvent::YIM> considers to be the end of a record. The arguments supplied to the callback will be the L<AnyEvent::YIM> object and the context hash.

=back

=cut

sub queue
{
  my ($self, $cb) = @_;

  push @{$self->{_queue}}, $cb;
}

=over

=item $yim->flush_queue;

Process the queued callbacks and clear the current context.

=back

=cut

sub flush_queue
{
  my ($self) = @_;
  DEBUG "flushing queue";

  while (my $cb = shift @{$self->{_queue}})
  {
    $cb->($self, $self->{_context});
  }

  $self->{_context} = {};
}

=over

=item $yim->msg($to, $msg);

Sends an IM to the specified user.

=back

=cut

sub msg
{
  my ($self, $to, $msg) = @_;

  my %msg = (
    YMSG_FIELD_USER_NAME()    => $self->{username},
    YMSG_FIELD_CURRENT_ID()   => $self->{username},
    YMSG_FIELD_TARGET_USER()  => $to,
    YMSG_FIELD_MSG()          => $msg
  );

  $self->send_data( create_message( \%msg, $self->{sessionid}, YMSG_USER_HAS_MSG() ) );
}

=head1 EXAMPLE

  # A quick and dirty implementation
  use AnyEvent;
  use AnyEvent::YIM;

  my $conn = AnyEvent::YIM->new(  username      => 'foo',
                                  password      => 'bar',
                                  on_disconnect => \&handle_disconnect,
                                  on_msg        => \&handle_msg,
                                  on_buddy      => \&handle_buddy );
  my $stdin = AnyEvent->io( fh    => \*STDIN,
                            poll  => "r",
                            cb    => \&handle_stdin );
  $conn->start();

  sub handle_disconnect {
    my ($yim, $msg) = @_;
    # re-connect on disconnect
    $yim->connect();
  }

  sub handle_buddy {
    my ($yim, $ctx) = @_;
    printf "%s is away: %s\n", $ctx->{buddy}, $ctx->{away_message} if $ctx->{away_message};
  }

  sub handle_msg {
    my ($yim, $ctx) = @_;
    my ($from, $to, $msg);
    print "*** ";
    if ($ctx->{ts}) {
      my @t = localtime($ctx->{ts});
      printf "%04d-%02d-%02d %02d:%02d:%02d ", $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0];
    }
    if ($ctx->{sender}) {
      print $ctx->{sender};
      $from = $ctx->{sender};
    }
    if ($ctx->{target_user}) {
      print " -> ";
      print $ctx->{target_user};
      $to = $ctx->{target_user};
    }
    $msg = $ctx->{msg};
    print " $msg\n";
    if ($from && $msg) {
      # strip html tags
      $msg =~ s/<[^>]+>//g;
      my ($cmd, @args) = split /\s+/, $msg;
      if ($cmd eq 'ping')
      {
        $yim->msg($from, 'pong');
      }
    }
  }

  sub handle_stdin {
    chomp(my $input = <STDIN>);
    my ($cmd, @args) = split /\s+/, $input;
    if ($cmd && lc($cmd) eq 'quit') {
      $conn->quit();
    }
    elsif ($cmd && lc($cmd) eq 'msg') {
      my $to  = shift @args;
      my $msg = join " ", @args;
      if ($to && $msg)
      {
        $conn->msg($to, $msg);
      }
    }
  }

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHOR

Nick Purvis <nep@yahoo-inc.com>

=head1 BUGS

Belligerent and numerous.

=cut

1;
