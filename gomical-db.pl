#!/usr/bin/env perl
use v5.14;
use warnings;
use utf8;
use DBI;
use LWP::UserAgent::Cached;
use Encode;
use File::Path qw/mkpath/;;
use Array::Uniq;
use Data::Dumper;

use FindBin qw($Bin);
use lib "$Bin/lib";
use GomiParse;

binmode(STDOUT, ":utf8");
$|++;

my $baseurl = 'http://www.city.sapporo.jp';
my $sleeptime = 1;

if (! -e "./tmp") {
        mkpath "./tmp" or die "cannot create ./tmp: $!";
}
my $ua = LWP::UserAgent::Cached->new(cache_dir => './tmp');
$ua->agent($ua->_agent . " Sapporo Gomi Calender Bot/0.1");

my $dbname = "gomical-2015.sqlite3";
if (-f $dbname) {
    unlink $dbname;
}

create_db();
insert_url();
insert_ku();
insert_gomical();

exit;



####################################
sub create_db {
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", undef, undef);
    my $sql = "CREATE TABLE m_gomi (id integer primary key autoincrement, gomi text);";
    my $sth = $dbh->prepare($sql);
    $sth->execute;
 
    $sql = "CREATE TABLE t_url (id integer primary key autoincrement, url text);";
    $sth = $dbh->prepare($sql);
    $sth->execute;

    $sql = "CREATE TABLE t_ku (id integer primary key autoincrement, ku text, url_id integer);";
    $sth = $dbh->prepare($sql);
    $sth->execute;

    $sql = "CREATE TABLE t_gomical (id integer primary key autoincrement, date date, youbi text, gomi_id integer, url_id integer);";
    $sth = $dbh->prepare($sql);
    $sth->execute;


    $sql = "INSERT INTO m_gomi (gomi) VALUES ('ごみ回収なし'), ('燃やせるごみ'), ('びん・缶・ペットボトル'), ('容器包装プラスチック'), ('雑がみ'), ('燃やせないごみ'), ('枝・葉・草');";
    $sth = $dbh->prepare($sql);
    $sth->execute;

}


####################################
sub insert_url {

    my $response = $ua->get("$baseurl/seiso/kaisyu/yomiage/index.html");
    my $html;
    if ($response->is_success) {
        $html = $response->content;
    } else {
        die $response->status_line;
    }
    sleep $sleeptime;

    # 区のURLを抽出
    my @ku_url;
    for my $line (split(/\n/, decode_utf8($html))) {
        if ($line =~ m|<p><a href="(/seiso/kaisyu/yomiage/.+\.html)">(\w+区)</a></p>|) {
            my $url = "$baseurl$1";
            push(@ku_url, $url);
        }
    }

    # uniq, sort
    @ku_url = uniq sort @ku_url;

    # 町のURLを抽出
    my @tyou_url;
    for my $url (@ku_url) {

        $response = $ua->get($url);
        if ($response->is_success) {
            $html = $response->content;
        } else {
            die $response->status_line;
        }
        sleep $sleeptime;
        $response = $ua->get($url);

        for my $ku_line (split("\n", decode_utf8($html))) {
            # 町のURLを探す
            if ($ku_line =~ m|<p><a href="(/seiso/kaisyu/yomiage/carender/.+\.html)">(.+)</a></p>|) {
                push(@tyou_url, "$baseurl$1");
            }

        }

    }

    # uniq, sortして表示
    @tyou_url = uniq sort @tyou_url;
    my $sql = "INSERT INTO t_url (url) values ";

    for my $url (@tyou_url) {
        $sql .= "(\"$url\"),";
    }
    
    $sql =~ s/,$/;/;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", undef, undef);
    my $sth = $dbh->prepare($sql);
    $sth->execute;
}

####################################
sub insert_ku {

    my $response = $ua->get("$baseurl/seiso/kaisyu/yomiage/index.html");
    my $html;
    if ($response->is_success) {
        $html = $response->content;
    } else {
        die $response->status_line;
    }
    sleep $sleeptime;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", undef, undef);
    my $select;
    my $sth;
    my @row;

    my $sql = "INSERT INTO t_ku (ku, url_id) VALUES ";

    for my $line (split(/\n/, decode_utf8($html))) {

        my $info;

        # 区のURL抜出
        if ($line =~ m|<p><a href="(/seiso/kaisyu/yomiage/.+\.html)">(\w+区)</a></p>|) {
            $info->{ku} = $2;
            $info->{ku_url} = "$baseurl$1";
        }

        # URLが見つかってたら次の処理
        if (defined $info->{ku_url}) {

            sleep $sleeptime;
            my $ku_response = $ua->get("$info->{ku_url}");
            my $ku_html;
            if ($ku_response->is_success) {
                $ku_html = $ku_response->content;
            } else {
                die $ku_response->status_line;
            }

            for my $ku_line (split("\n", decode_utf8($ku_html))) {

                # 町のURLを探す
                if ($ku_line =~ m|<p><a href="(/seiso/kaisyu/yomiage/carender/.+\.html)">(.+)</a></p>|) {
                    $info->{tyou} = $2;
                    $info->{tyou_url} = "$baseurl$1";

                    $select = "select id from t_url where url = '" . $info->{tyou_url} . "';";
                    $sth = $dbh->prepare($select);
                    $sth->execute;
                    @row = $sth->fetchrow_array;

                    $sql .= "('$info->{ku} $info->{tyou}', $row[0]),";
                }

                # 繰り返し使うようにクリアしておく
                $info->{tyou_url} = undef;
            }
        }
    }

    $sql =~ s/,$/;/;
    $sth = $dbh->prepare($sql);
    $sth->execute;
}


####################################
sub insert_gomical {

    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", undef, undef);
    my $select = "select id,url from t_url order by id;";
    my $sth = $dbh->prepare($select);
    $sth->execute;
    my @sqls;

    while (my @row = $sth->fetchrow_array) {

        my $response = $ua->get($row[1]);
        my $tyou_html;
        if ($response->is_success) {
            $tyou_html = $response->content;
        } else {
            die $response->status_line;
        }

        for my $tyou_line (split("\n", decode_utf8($tyou_html))) {

            # スペースで開始している場合があるので削除
            $tyou_line =~ s/^\s//g;

            # 音声読み上げ部分からカレンダーを生成
            if ($tyou_line =~ /^平成(\d)/) {
                $tyou_line =~ s/<.+>//;
                $tyou_line =~ s/\r//;

                my @gomical = GomiParse::gomi_parse($tyou_line);
                for my $gomiline (@gomical) {
                    my @lines = split(", ", $gomiline);

                    $select = "select id from m_gomi where gomi = '" . $lines[2] . "'";
                    my $sth2 = $dbh->prepare($select);
                    $sth2->execute;
                    my @gomirow = $sth2->fetchrow_array;
                    my $gomisyurui = $gomirow[0];

                    push(@sqls, "INSERT INTO t_gomical (date, youbi, gomi_id, url_id) VALUES ('$lines[0]', '$lines[1]', $gomisyurui, $row[0]);");

                }

            }

        }
    }

    $sth->finish;
    $dbh->disconnect();

    $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", undef, undef, { AutoCommit => 0});
    $dbh->do('BEGIN');
    for my $sql (@sqls) {
        $sth = $dbh->prepare($sql);
        $sth->execute;
    }
    $dbh->do('COMMIT');
    $sth->finish;
    $dbh->disconnect();
}
