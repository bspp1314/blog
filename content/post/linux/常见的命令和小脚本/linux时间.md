---
title: "linux时间处理"
date: 2021-03-19T18:03:51+08:00
draft: true
---

Linux下date命令用法

```
date [OPTION]… [+FORMAT]
date [-u|--utc|--universal] [MMDDhhmm[[CC]YY][.ss]]
```

date命令参数

```shell
-d, –date=STRING  显示STRING指定的时间
-f, –file=DATEFILE  类似–date参数显示DATEFILE文件中的每行时间
-ITIMESPEC, –iso-8601[=TIMESPEC]  以ISO  8601 格式显示日期/时间。TIMESPEC为”date”(只显示日期)、”hours”、”minutes”、”senconds”(显示时间精度)之一，默认为”date”。
-r, –reference=FILE  显示文件的最后修改时间
-R, –rfc-2822  以RFC-2822兼容日期格式显示时间
-s, –set=STRING  设置时间为STRING
-u, –utc, –universal  显示或设定为Coordinated Universal Time时间格式
```
date命令输出显示格式
```
%%    字符%
%a     星期的缩写(Sun..Sat)
%A    星期的完整名称 (Sunday..Saturday)
%b     月份的缩写(Jan..Dec)
%B     月份的完整名称(January..December)
%c     日期时间(Sat Nov 04 12:02:33 EST 1989)
%C     世纪(年份除100后去整) [00-99]
%d     一个月的第几天(01..31)
%D     日期(mm/dd/yy)
%e     一个月的第几天 ( 1..31)
%F    日期，同%Y-%m-%d
%g     年份(yy)
%G     年份(yyyy)
%h     同%b
%H    小时(00..23)
%I     小时(01..12)
%j     一年的第几天(001..366)
%k     小时( 0..23)
%l      小时( 1..12)
%m    月份(01..12)
%M    分钟(00..59)
%n     换行
%N     纳秒(000000000..999999999)
%p     AM or PM
%P     am or pm
%r     12小时制时间(hh:mm:ss [AP]M)
%R    24小时制时间(hh:mm)
%s     从00:00:00 1970-01-01 UTC开始的秒数
%S     秒(00..60)
%t     制表符
%T    24小时制时间(hh:mm:ss)
%u     一周的第几天(1..7);  1 表示星期一
%U     一年的第几周，周日为每周的第一天(00..53)
%V     一年的第几周，周一为每周的第一天 (01..53)
%w     一周的第几天 (0..6);  0 代表周日
%W    一年的第几周，周一为每周的第一天(00..53)
%x     日期(mm/dd/yy)
%X     时间(%H:%M:%S)
%y     年份(00..99)
%Y     年份 (1970…)
%z     RFC-2822 风格数字格式时区(-0500)
%Z     时区(e.g., EDT), 无法确定时区则为空
```



一些常见的例子

```shell
date
2021年 04月 25日 星期日 14:38:38 CST

date -d '2021-04-25 14:38:39'
2021年 04月 25日 星期日 14:38:39 CST

date -d "2021-04-25 14:38:39" "+%Y-%m-%d %H:%M"
2021-04-25 14:38

#时间戳
date -d "2021-04-25 14:38:39" "+%s"
1619332719

date -d @1619332719
2021年 04月 25日 星期日 14:38:39 CST

date -d @1619332719 "+%Y-%m-%d %H:%M"
2021-04-25 14:38

date -d "2020-04-06+2days2hour3second"
2020年 04月 08日 星期三 02:00:03 CST

```

遍历时间

```shell
start_date=2021-04-01
end_date=2021-04-30 
start_sec=`date -d "$start_date" "+%s"`
end_sec=`date -d "$end_date" "+%s"`
for((i=start_sec;i<=end_sec;i+=86400)); do
    day=$(date -d "@$i" "+%Y-%m-%d")
    echo $day
done
```



