gomical
=======

札幌市の音声読み上げ用家庭ごみ収集日カレンダーを利用した何か

* gomical-db.pl
  ゴミカレンダーが詰まったsqlite3を吐き出す

使い方
=====

ゴミカレンダーが詰まったsqlite3の生成

```
./gomical-db.pl
```

出てきたsqlite3のやつでのカレンダーの表示例

```
select ku,date,gomi from t_gomical, m_gomi,t_ku where t_gomical.gomi_id = m_gomi.id and t_gomical.url_id = t_ku.url_id and t_ku.ku like '%北1条%' order by t_ku.id, date limit 365;
```

