package AnyEvent::YIM::Constants;

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
# $Id: Constants.pm 292313 2011-01-07 18:39:26Z nep $

use Log::Log4perl qw(:easy);

use base qw(Exporter);
use vars qw(@C_GENERAL
            @C_YMSG
            @EXPORT_OK
           );

@C_GENERAL = qw(MSGR_DEFAULT_HOST
                MSGR_DEFAULT_PORT
                LOGIN_DEFAULT_HOST
                UTF_NULL
                YMSG_HEADER
                YMSG_VERSION
                YMSG_VENDOR_ID
                YMSG_CAP_MATRIX
               );

@C_YMSG = qw(YMSG_USER_HAS_MSG
             YMSG_USER_LOGIN_2
             YMSG_HELO
             YMSG_FIELD_USER_NAME
             YMSG_FIELD_CURRENT_ID
             YMSG_FIELD_ACTIVE_ID
             YMSG_FIELD_USER_ID
             YMSG_FIELD_SENDER
             YMSG_FIELD_TARGET_USER
             YMSG_FIELD_PASSWORD
             YMSG_FIELD_BUDDY
             YMSG_FIELD_NUM_BUDDIES
             YMSG_FIELD_NUM_EMAILS
             YMSG_FIELD_AWAY_STATUS
             YMSG_FIELD_SESSION_ID
             YMSG_FIELD_IP_ADDRESS
             YMSG_FIELD_FLAG
             YMSG_FIELD_MSG
             YMSG_FIELD_TIME
             YMSG_FIELD_ERROR
             YMSG_FIELD_PORT
             YMSG_FIELD_MAIL_SUBJECT
             YMSG_FIELD_AWAY_MESSAGE
             YMSG_FIELD_CUSTOM_DND_STATUS
             YMSG_FIELD_CHALLENGE
             YMSG_FIELD_UTF8_FLAG
             YMSG_FIELD_ICON_CHECKSUM
             YMSG_FIELD_CAP_MATRIX
             YMSG_FIELD_HASH
             YMSG_FIELD_LOGIN_Y_COOKIE
             YMSG_FIELD_LOGIN_T_COOKIE
             YMSG_FIELD_START_OF_RECORD
             YMSG_FIELD_END_OF_RECORD
             YMSG_FIELD_START_OF_LIST
             YMSG_FIELD_END_OF_LIST
             YMSG_FIELD_CRUMB_HASH
            );

@EXPORT_OK = ( @C_GENERAL, @C_YMSG );

# general stuff
use constant MSGR_DEFAULT_HOST  => 'scs.msg.yahoo.com';
use constant MSGR_DEFAULT_PORT  => 5050;
use constant LOGIN_DEFAULT_HOST => 'login.yahoo.com';
use constant UTF_NULL           => "\300\200";
use constant YMSG_HEADER        => 'YMSG';
use constant YMSG_VERSION       => 16;
use constant YMSG_VENDOR_ID     => 0;
use constant YMSG_CAP_MATRIX    => 2097098; # really have no idea what this is

# protocol stuff
use constant YMSG_USER_HAS_MSG  => 6;
use constant YMSG_USER_LOGIN_2  => 84;
use constant YMSG_HELO          => 87;

# fields
use constant YMSG_FIELD_USER_NAME         => 0;   # login id
use constant YMSG_FIELD_CURRENT_ID        => 1;   # current user id
use constant YMSG_FIELD_ACTIVE_ID         => 2;   # active user id
use constant YMSG_FIELD_USER_ID           => 3;   # user id
use constant YMSG_FIELD_SENDER            => 4;   # sender's name
use constant YMSG_FIELD_TARGET_USER       => 5;   # target user name
use constant YMSG_FIELD_PASSWORD          => 6;   # password
use constant YMSG_FIELD_BUDDY             => 7;   # buddy's user id
use constant YMSG_FIELD_NUM_BUDDIES       => 8;   # number of buddies
use constant YMSG_FIELD_NUM_EMAILS        => 9;   # number of emails
use constant YMSG_FIELD_AWAY_STATUS       => 10;  # away status code
use constant YMSG_FIELD_SESSION_ID        => 11;  # session id
use constant YMSG_FIELD_IP_ADDRESS        => 12;  # ip address
use constant YMSG_FIELD_FLAG              => 13;  # flag
use constant YMSG_FIELD_MSG               => 14;  # message
use constant YMSG_FIELD_TIME              => 15;  # time
use constant YMSG_FIELD_ERROR             => 16;  # error message
use constant YMSG_FIELD_PORT              => 17;  # port number
use constant YMSG_FIELD_MAIL_SUBJECT      => 18;  # mail subject
use constant YMSG_FIELD_AWAY_MESSAGE      => 19;  # away message
use constant YMSG_FIELD_CUSTOM_DND_STATUS => 47;  # do not disturb with custom status
use constant YMSG_FIELD_CHALLENGE         => 94;  # challenge
use constant YMSG_FIELD_UTF8_FLAG         => 97;  # 1 if custom message is in utf8
use constant YMSG_FIELD_ICON_CHECKSUM     => 192; # friend icon checksum
use constant YMSG_FIELD_CAP_MATRIX        => 244; # bitmask capability matrix
use constant YMSG_FIELD_HASH              => 252; # field hash
use constant YMSG_FIELD_LOGIN_Y_COOKIE    => 277; # Y-cookie
use constant YMSG_FIELD_LOGIN_T_COOKIE    => 278; # T-cookie
use constant YMSG_FIELD_START_OF_RECORD   => 300; # begin record entry, there can be multiple records in a list
use constant YMSG_FIELD_END_OF_RECORD     => 301; # end record entry
use constant YMSG_FIELD_START_OF_LIST     => 302; # begin a list that may contain multiple records
use constant YMSG_FIELD_END_OF_LIST       => 303; # end of list
use constant YMSG_FIELD_CRUMB_HASH        => 307; # login crumb hash

1;
