package AnyEventYIMTester;

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
use AnyEvent::TLS;
use Carp qw(croak);
use Exporter qw(import);
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);

our @EXPORT = qw( run_tests
                );

Log::Log4perl::init("$Bin/conf/log4perl.conf");

my $auth_server_address = '127.0.0.1';
my $auth_server_port    = 9443;
my $auth_server_pid     = undef;
my $auth_server_cv      = undef;
my $auth_server_content = {
  '/config/pwtoken_get'   => "0\nymsgr=YMSGR_TOKEN-\npartnerid=YMSGR_PARTNERID-\n",
};

END
{
  https_stop();
}

sub run_tests(&)
{
  my $cb = shift;

  chdir $Bin;
  system( "rm -rf $Bin/.tmp" );
  mkdir "$Bin/.tmp" unless -d "$Bin/.tmp";

  if (https_start())
  {
    $cb->();
  }
}

sub https_start
{
  return if $auth_server_pid;
  $auth_server_pid = fork();
  if ($auth_server_pid)
  {
    INFO "spawned auth_server (pid $auth_server_pid)";
    return 1;
  }
  INFO "creating server!";
  $auth_server_cv = AnyEvent->condvar;
  tcp_server(
    $auth_server_address,
    $auth_server_port,
    sub {
      my ($fh, $host, $port) = @_;
      INFO "received connection from $host:$port";
      my $handle;
      $handle = AnyEvent::Handle->new(
        fh          => $fh,
        tls         => 'accept',
        tls_ctx     => {
          cert_file => "$Bin/conf/yimserver.cert",
          key_file  => "$Bin/conf/yimserver.key"
        },
        on_eof      => sub {
          $handle->destroy;
        },
        on_error    => sub {
          my ($hdl, $fatal, $msg) = @_;
          DEBUG "error received: $msg";
          $handle->destroy;
        },
      );
      $handle->push_read( regex => qr/\r?\n\r?\n/, sub {
        my ($hdl, $data) = @_;
        #DEBUG "headers: $data";
        if ($data =~ m/GET\s+(\S+)\s+/)
        {
          my ($path, $query) = split /\?/, $1;
          if (exists $auth_server_content->{$path})
          {
            $handle->push_write(  "HTTP 200 OK\n"
                                . "Connection: close\n"
                                . "Content-Length: " . length($auth_server_content->{$path}) . "\n"
                                . "Content-Type: text/plain\n\n"
                                . $auth_server_content->{$path} );
          }
          else
          {
            $handle->push_write(  "HTTP 200 OK\n"
                                . "Connection: close\n"
                                . "Content-Length: 4\n"
                                . "Content-Type: text/plain\n\n"
                                . "foo\n" );
          }
        }
        $handle->push_shutdown;
      });
    }
  );
  $auth_server_cv->recv;
  INFO "done creating server!";
  return 0;
}

sub https_stop
{
  return unless $auth_server_pid;
  $auth_server_cv->send if $auth_server_cv;
  INFO "killing $auth_server_pid";
  kill( TERM => $auth_server_pid );
  undef $auth_server_pid;
  sleep 3;
}

1;
