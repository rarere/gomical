#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Encode;
use Calendar::Simple;

my $line;

#$line = "平成25年9月の収集日です。燃やせるごみは、毎週火曜日と金曜日です。びん・缶・ペットボトルは毎週月曜日、容器包装プラスチックは毎週木曜日です。雑がみは11日、25日の水曜日です。燃やせないごみは4日の水曜日です。枝・葉・草は18日の水曜日です。";
#$line = "平成26年4月の収集日です。燃やせるごみは、毎週月曜日と木曜日です。びん・缶・ペットボトルは毎週火曜日、容器包装プラスチックは毎週金曜日です。雑がみは2日、16日、30日の水曜日です。燃やせないごみは9日の水曜日です。４月は枝・葉・草の収集はありません。";
#$line = "平成26年6月の収集日です。燃やせるごみは、毎週火曜日と金曜日です。びん・缶・ペットボトルは毎週木曜日、容器包装プラスチックは毎週水曜日です。雑がみは9日、23日の月曜日です。燃やせないごみは2日、30日の月曜日です。枝・葉・草は16日の月曜日です。";
$line = "平成25年9月の収集日です。燃やせるごみは、毎週火曜日と金曜日です。びん・缶・ペットボトルは毎週木曜日、容器包装プラスチックは毎週水曜日です。雑がみは9日、23日の月曜日です。燃やせないごみは16日の月曜日です。枝・葉・草は2日、30日の月曜日です。";


my $info = gomiparse($line);
my $cal = calendar($info->{month}, $info->{year});
my @gomical = gominohi($info, $cal);

print encode_utf8($line)."\n";
print join("\n", @gomical)."\n";


sub gomiparse {
    my ($line) = @_;

    my $info = {};

    if ($line =~ /平成(\d+)年(\d+)月/) {
        $info->{year} = $1 + 2000 - 12;
        $info->{month} = $2;
    }

    if ($line =~ /燃やせるごみは、毎週(\w+)曜日と(\w+)曜日です/) {
        $info->{moyaseru} = [youbi2num($1), youbi2num($2)];
    }

    if ($line =~ /びん・缶・ペットボトルは毎週(\w+)曜日/) {
        $info->{bin} = [youbi2num($1)];
    }

    if ($line =~ /容器包装プラスチックは毎週(\w+)曜日/) {
        $info->{pura} = [youbi2num($1)];
    }

    if ($line =~ /雑がみは(.+)日の(\w+)曜日です。(燃やせない|\w+月は燃やせない)/) {
        $info->{zatsugami} = [getdays($1)];
    }

    if ($line =~ /燃やせないごみは(.+)日の(\w+)曜日です。(枝|\w+月は枝)/) {
        $info->{moyasenai} = [getdays($1)];
    }

    if ($line =~ /枝・葉・草は(.+)の(\w+)曜日です/) {
        $info->{eda} = [getdays($1)];
    } elsif ($line =~ /枝・葉・草は(.+)日の収集です/) {
        $info->{eda} = [getdays($1)];
    } elsif ($line =~ /枝・葉・草の収集はありません/) {
        $info->{eda} = [''];
    }

    return $info;
}


sub youbi2num {
    my ($word) = @_;
    
    my $num = 0;
    if ($word eq '日') {
        $num = 0;
    } elsif ($word eq '月') {
        $num = 1;
    } elsif ($word eq '火') {
        $num = 2;
    } elsif ($word eq '水') {
        $num = 3;
    } elsif ($word eq '木') {
        $num = 4;
    } elsif ($word eq '金') {
        $num = 5;
    } elsif ($word eq '土') {
        $num = 6;
    }
    return $num;
}

sub num2youbi {
    my ($num) = @_;
    my $word = "";
    if ($num == 0) {
        $word = "日";
    } elsif ($num == 1) {
        $word = "月";
    } elsif ($num == 2) {
        $word = "火";
    } elsif ($num == 3) {
        $word = "水";
    } elsif ($num == 4) {
        $word = "木";
    } elsif ($num == 5) {
        $word = "金";
    } elsif ($num == 6) {
        $word = "土";
    }
    return $word;
}

sub getdays {
    my ($line) = @_;
    $line //= "";
    $line =~ s/日//g;
    $line =~ s/、/ /g;
    my @lines = split(" ", $line);
    return @lines;
}

sub gominohi {
    my ($info, $cal) = @_;

    my @gomi;
    my $gomiflag=0;

    for (my $i = 0; $i < @$cal; $i++) {

        for (my $j = 0; $j < 7; $j++) {

            my $day = $cal->[$i]->[$j];

            if (defined $day) {

                my @count = grep { $_ eq $j } @{$info->{moyaseru}};
                unless (@count == 0) {
                    push(@gomi, encode_utf8("$info->{year}/$info->{month}/$day, " . num2youbi($j) . ", 燃やせるごみ"));
                    $gomiflag=1;
                }

                @count = grep { $_ eq $j } @{$info->{bin}};
                unless (@count == 0) {
                    push(@gomi, encode_utf8("$info->{year}/$info->{month}/$day, " . num2youbi($j) . ", びん・缶・ペットボトル"));
                    $gomiflag=1;
                }

                @count = grep { $_ eq $j } @{$info->{pura}};
                unless (@count == 0) {
                    push(@gomi, encode_utf8("$info->{year}/$info->{month}/$day, " . num2youbi($j) . ", 容器包装プラスチック"));
                    $gomiflag=1;
                }

                @count = grep { $_ eq $day } @{$info->{zatsugami}};
                unless (@count == 0) {
                    push(@gomi, encode_utf8("$info->{year}/$info->{month}/$day, " . num2youbi($j) . ", 雑がみ"));
                    $gomiflag=1;
                }

                @count = grep { $_ eq $day } @{$info->{moyasenai}};
                unless (@count == 0) {
                    push(@gomi, encode_utf8("$info->{year}/$info->{month}/$day, " . num2youbi($j) . ", 燃やせないごみ"));
                    $gomiflag=1;
                }

                @count = grep { $_ eq $day } @{$info->{eda}};
                unless (@count == 0) {
                    push(@gomi, encode_utf8("$info->{year}/$info->{month}/$day, " . num2youbi($j) . ", 枝・葉・草"));
                    $gomiflag=1;
                }

                if ($gomiflag == 0) {
                    push(@gomi, encode_utf8("$info->{year}/$info->{month}/$day, " . num2youbi($j) . ", ごみ回収なし"));
                }
                $gomiflag=0;
            }
        }
    }

    return @gomi;
}
