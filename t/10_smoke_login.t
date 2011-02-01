#!/usr/bin/env perl -w

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

use Test::More qw(no_plan);
use FindBin qw($Bin);
use Carp qw(confess);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use AnyEventYIMTester;

run_tests
{
  print "Hello, World!\n";
  sleep 10;
  print "Goodbye, World!\n";
};

1;
