#!/usr/bin/perl
# --
# bin/otrs.PostMaster.pl - the global eMail handle for email2db
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

# to get it readable for the webserver user and writable for otrs
# group (just in case)

umask 007;

use Getopt::Std;
use Kernel::System::ObjectManager;

# get options
my %Opts;
getopt( 'qtd', \%Opts );
if ( $Opts{h} ) {
    print "otrs.PostMaster.pl - OTRS cmd postmaster\n";
    print "Copyright (C) 2001-2014 OTRS AG, http://otrs.com/\n";
    print
        "usage: otrs.PostMaster.pl -q <QUEUE> -t <TRUSTED> (default is trusted, use '-t 0' to disable trusted mode)\n";
    exit 1;
}
if ( !$Opts{d} ) {
    $Opts{d} = 0;
}
if ( !defined( $Opts{t} ) ) {
    $Opts{t} = 1;
}
if ( !$Opts{q} ) {
    $Opts{q} = '';
}

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'OTRS-otrs.PostMaster.pl',
    },
);

# Wrap the majority of the script in an "eval" block so that any
# unexpected (but probably transient) fatal errors (such as the
# database being unavailable) can be trapped without causing a
# bounce
eval {

    # create needed objects

    # debug info
    if ( $Opts{d} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => 'Global OTRS email handle (otrs.PostMaster.pl) started...',
        );
    }

    # get email from SDTIN
    my @Email = <STDIN>;
    if ( !@Email ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no email on STDIN!',
        );
        exit 1;
    }

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::PostMaster' => {
            Email   => \@Email,
            Trusted => $Opts{'t'},
            Debug   => $Opts{'d'},
        },
    );
    my @Return = $Kernel::OM->Get('Kernel::System::PostMaster')->Run( Queue => $Opts{'q'} );
    if ( !$Return[0] ) {
        die "Can't process mail, see log sub system!";
    }

    # debug info
    if ( $Opts{d} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => 'Global OTRS email handle (otrs.PostMaster.pl) stopped.',
        );
    }
};

if ($@) {

    # An unexpected problem occurred (for example, the database was
    # unavailable). Return an EX_TEMPFAIL error to cause the mail
    # program to requeue the message instead of immediately bouncing
    # it; see sysexits.h. Most mail programs will retry an
    # EX_TEMPFAIL delivery for about four days, then bounce the
    # message.)
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => $@,
    );
    exit 75;
}

exit 0;
