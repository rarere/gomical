package GomiParse;

use strict;
use warnings;
use utf8;
use Calendar::Simple;

our $VERSION = "0.02";

sub gomi_parse {
    my ($line) = @_;
    
    my $info = gomi_wakeru($line);
    my $cal = calendar($info->{month}, $info->{year});
    my @gomical = gomi_no_hi($info, $cal);

    return @gomical;
}

sub gomi_wakeru {
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
        my $zatsugamiline = $1;
        if ($zatsugamiline =~ /日\d、\d/) {
            $zatsugamiline =~ s/、//g;
        }
        $info->{zatsugami} = [get_days($zatsugamiline)];
    } elsif ($line =~ /雑がみ(.+)日の(\w+)曜日です。(燃やせない|\w+月は燃やせない)/) {
        $info->{zatsugami} = [get_days($1)];
    }

    if ($line =~ /燃やせないごみは(.+)日の(\w+)曜日です。(枝|\w+月は枝)/) {
        $info->{moyasenai} = [get_days($1)];
    }

    if ($line =~ /枝・葉・草は(.+)の(\w+)曜日です/) {
        $info->{eda} = [get_days($1)];
    } elsif ($line =~ /枝・葉・草は、(.+)の(\w+)曜日です/) {
        $info->{eda} = [get_days($1)];
    } elsif ($line =~ /枝・葉・草(.+)の(\w+)曜日です/) {
        $info->{eda} = [get_days($1)];
    } elsif ($line =~ /枝・葉・草は(.+)日の収集です/) {
        $info->{eda} = [get_days($1)];
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

sub get_days {
    my ($line) = @_;
    $line //= "";
    $line =~ s/日/ /g;
    $line =~ s/、/ /g;
    $line =~ tr/ //s; # 連続スペースは1つに
    my @lines = split(" ", $line);
    return @lines;
}

sub gomi_no_hi {
    my ($info, $cal) = @_;

    my @gomi;

    for (my $i = 0; $i < @$cal; $i++) {

        for (my $j = 0; $j < 7; $j++) {

            my $day = $cal->[$i]->[$j];

            if (defined $day) {

                my $year  = sprintf("%02d", $info->{year});
                my $month = sprintf("%02d", $info->{month});
                $day      = sprintf("%02d", $day);

                # 12/31, 1/1, 1/2はゴミ回収なし
                if ("-$month-$day" eq "-12-31") {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", ごみ回収なし");
                    next;
                }
                if ("-$month-$day" eq "-01-01") {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", ごみ回収なし");
                    next;
                }
                if ("-$month-$day" eq "-01-02") {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", ごみ回収なし");
                    next;
                }

                if (grep { $_ eq $j } @{$info->{moyaseru}}) {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", 燃やせるごみ");
                    next;
                }

                if (grep { $_ eq $j } @{$info->{bin}}) {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", びん・缶・ペットボトル");
                    next;
                }

                if (grep { $_ eq $j } @{$info->{pura}}) {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", 容器包装プラスチック");
                    next;
                }

                if (grep { $_ eq $day } @{$info->{zatsugami}}) {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", 雑がみ");
                    next;
                }

                if (grep { $_ eq $day } @{$info->{moyasenai}}) {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", 燃やせないごみ");
                    next;
                }

                if (grep { $_ eq $day } @{$info->{eda}}) {
                    push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", 枝・葉・草");
                    next;
                }

                push(@gomi, "$year-$month-$day, " . num2youbi($j) . ", ごみ回収なし");

            }
        }
    }

    return @gomi;
}

1;

__END__
