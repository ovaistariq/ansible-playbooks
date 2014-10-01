
# #############################################################################
# # pt_online_schema_change_plugin
# # #############################################################################
{
package pt_online_schema_change_plugin;

use strict;
use constant PTDEBUG => $ENV{PTDEBUG} || 0;

sub new {
    my ($class, %args) = @_;
    my $self = { %args };
    my $dbh = $self->{cxn}->dbh();

    return bless $self, $class;
}

sub init {
    my ($self, %args) = @_;
}

sub before_update_foreign_keys {
    my ($self, %args) = @_;
    my $dbh = $self->{cxn}->dbh();

    my $sth = $dbh->prepare('STOP SLAVE SQL_THREAD');
    print "Executing " . $sth->{Statement} . " \n";

    return $sth->execute();
}

sub after_update_foreign_keys {
    my ($self, %args) = @_;
    my $dbh = $self->{cxn}->dbh();

    my $sth = $dbh->prepare('START SLAVE');
    print "Executing " . $sth->{Statement} . " \n";

    return $sth->execute();
}

}
1;
