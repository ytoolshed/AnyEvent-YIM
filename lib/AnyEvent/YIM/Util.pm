package AnyEvent::YIM::Util;

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

use Log::Log4perl qw(:easy);

use AnyEvent::Handle;
use AnyEvent::YIM::Constants qw(YMSG_HEADER
                                YMSG_VERSION
                                YMSG_VENDOR_ID
                                UTF_NULL
                               );

use base qw(Exporter);
use vars qw(@EXPORT_OK
            $UTF_NULL
           );

@EXPORT_OK = qw(create_message
                parse_message
                https_get
               );

BEGIN
{
  $UTF_NULL = UTF_NULL();
}

sub parse_message
{
  my ($message) = @_;
  DEBUG "parsing message: $message";

  # parse the header
  my ($head,$version,$vendor,$length,$cmd,$status,$sid) = unpack('a4nnnnNN',substr($message,0,20,''));

  # parse the body
  my @body = split(/$UTF_NULL/,substr($message,0,$length,''));

  return {
    'header' => {
      'head'    => $head,
      'version' => $version,
      'vendor'  => $vendor,
      'length'  => $length,
      'cmd'     => $cmd,
      'status'  => $status,
      'sid'     => $sid
    },
    'body' => \@body,
    'buff' => $message
  };
}

sub create_message
{
  my ($info, $sessionid, $command) = @_;

  my $status  = 0; # TODO: what's this?
  my $data    = "";

  foreach my $key (keys %{$info})
  {
    $data .= $key . $UTF_NULL . $info->{$key} . $UTF_NULL;
  }

  my $header = pack('a4nnnnNN',
    YMSG_HEADER(),
    YMSG_VERSION(),
    YMSG_VENDOR_ID(),
    length($data),
    $command,
    $status,
    $sessionid
  );

  return $header . $data;
}

sub https_get
{
  my ($host, $uri, $cb) = @_;

  my ($handle, $response, $header, $body);

  $handle = AnyEvent::Handle->new(
    connect => [ $host, 'https' ],
    tls => 'connect',
    on_error => sub {
      $cb->("HTTP/1.0 500 $!");
      $handle->destroy;
    },
    on_eof => sub {
      $cb->($response, $header, $body);
      $handle->destroy;
    }
  );

  DEBUG sprintf "GET https://%s%s", $host, $uri;

  $handle->push_write(
    sprintf "GET %s HTTP/1.0\015\012\015\012",
    $uri, $host );

  $handle->push_read( line => sub {
    my ($hdl, $line) = @_;
    $response = $line;
  } );

  $handle->push_read( line => "\015\012\015\012", sub {
    my ($hdl, $line) = @_;
    $header = $line;
  } );

  $handle->on_read( sub {
    my ($hdl) = @_;
    $body .= $handle->rbuf;
    $handle->rbuf = "";
  } );
}

1;
