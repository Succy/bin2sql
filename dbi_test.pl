#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use Data::Dumper;

# db config
my $db_user = "root";
my $db_pass = "123456";
my $db_host = "192.168.3.106";
my $db_port = 3306;

my $dbh = DBI->connect("DBI:mysql:database=information_schema;host=$db_host;port=$db_port", "$db_user", "$db_pass") or die "Unable to connect: $DBI::errstr\n";
my $sql = "select column_name, table_name from information_schema.columns where table_schema='demo' order by table_name asc, ordinal_position asc";
my $sth = $dbh->prepare($sql);
$sth->execute();
my %tb_schemas = ();
while (my @row = $sth->fetchrow_array()) {
    my ($col_name, $table_name) = @row;
    # print "col: $col_name, tb_name: $table_name\n";
    if (exists($tb_schemas{$table_name})) {
        # 使用指针来节约空间
        my $p_arr = \@{$tb_schemas{$table_name}};
        push @$p_arr, $col_name;
        $tb_schemas{$table_name} = $p_arr;
        print "MyPointer:$p_arr\n"
    }
    else {
        my @arr = ($col_name);
        $tb_schemas{$table_name} = \@arr;
        my $pointer = \@arr;
        print "Pointer:$pointer\n"
    }
}
# 这个神器打印hash真的好用！
print Dumper(\%tb_schemas);

$sth->finish();
$dbh->disconnect();


my @arr = qw{A B C D};
print join ',' , map "'$_'", @arr;
