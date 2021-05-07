# MySQL binlog转Sql工具

## 简介

### 工具起源

​		一开始，我只想找一个工具去解析mysql的binlog，以便于不时之需恢复数据，首当其冲肯定是想到mysql官方都提供了哪些，因此最开始是研究mysqlbinlog这个工具的，但是后面发现，它只能指定到database级别，并不能到table级别，而且有时候我们不是很关心create/drop之类的sql，比较关心DML，甚至关心我能不能只过滤出来指定的表指定的类型的SQL语句。也正是由于这个原因，我在网上寻找了很多这方便的工具，总结一下网上的工具主要都是如下两方面的：

1、通过伪装成slave拉取binlog来进行处理。以[binlog2sql](https://github.com/danfengcao/binlog2sql)为代表.

2、直接解析binlog文件，然后对数据做二次过滤的，以mysqlbinlog和本程序为代表。

​		然而binlog2sql在我使用过程中，总得来说也还不错的，就是其运行有点慢，我就想能不能有一个工具可以直接解析binlog又能满足我的要求的？寻求了一圈之后我发现并没有很符合我的要求的，于是我打算自己写一个。一开始我并不打算使用Perl语言写的，因为我对这个语言不是很熟悉，我是想着用go或者python写的，但是在我用go和python写了一段时间之后，都发现在处理文本这块有些许不足，可能也是因为我的水平问题吧，因此我选择了Perl语言，简单看了下语法和网上的一些案例之后，就开始写了，Perl同时有着强大的正则表达式和能直接运行shell命令的强大特点让我在编写过程中节约了很多时间。

​		这个小工具采用了mysqlbinlog作为主要产生数据的工具，通过Perl调用mysqlbinlog获取到可读的binlog数据，然后再进行流式处理，从而达到目的，在目前我的使用过程中发现，这样的配合执行速度还是不错的。由于我的Perl水平实在是有限，程序也难免会有错误，如果发现有错误或者有更好的写法，欢迎issue和pr或者直接邮件联系本人`1459307744@qq.com`。



### 功能介绍

这是一款使用perl语言开发的mysql binlog转sql的工具，主要是弥补了`mysqlbinlog`这个自带的工具不能指定表名的不足，主要包含如下功能

+ 支持指定start-datetime和stop-datetime解析binlog。
+ 支持指定start-position和stop-position解析binlog。
+ 支持解析指定的databases、指定的tables。
+ 支持指定dml类型，仅支持`INSERT、UPDATE、DELETE`。
+ 支持`only-dml`属性，如果指定该属性，则不会输出dml以外的sql。
+ 支持闪回(flashback)
+ 支持获取远端服务器的Binlog

### 设计思路

整个脚本设计思路非常简单，大致分为三步

1、通过操作指定的数据源，获取到information_schema存储的表字段信息。

2、通过mysqlbinlog工具，获取指定binlog文件。

3、解析binlog，提取出来sql，替换占位符为字段名，还原SQL，通过反转SQL，起到闪回的目的。

经过本人实践，依托Perl和mysqlbinlog，其性能还是不错的，整个过程都是使用流式处理的，理论上可以应对比较大的binlog文件，但是本人公司内毕竟需要恢复数据的场景并不是那么多(如果非常多误操作，怕是饭碗不保了)，因此可能有些地方会略为片面，有需要的可以自行进行测试和修改或者提ISSUE。

## 注意事项

*这里的内容非常关键，请务必注意*

Q：如果我把表删了，还能恢复数据吗？

A：如果你把表删了，有备份在，并且表结构也没发生变化，可以恢复的。

Q：我就是把表删了，但是没有重建表结构，能把这个表之前发生的SQL操作恢复吗？

A：不可以。因为我们依赖`information_schema`获取表的字段名和顺序，根据这个替换binlog的占位符，如果把表删了，并且没有先恢复表结构，会忽略DML的解析的。

Q：如果表结构发生了变化，能恢复吗？

A：不能，都改表了，你恢复以前的数据有什么意义？就算强行解析出来，可能都错位了或者这个SQL就是有问题的了

## 安装和配置

> github: [https://github.com/Succy/bin2sql](https://github.com/Succy/bin2sql)
>
> gitee: [https://gitee.com/succy/bin2sql](https://gitee.com/succy/bin2sql)

### 免安装版本

直接到release下载可执行文件，到Linux系统，添加可执行权限就可以运行了

### 源码安装

首先说明一下，我都是在Linux下测试的，并且也是针对Linux环境开发的，因为Perl语言在很多Linux发行版都内置，我所使用的是CentOS7，内置的Perl是5.16.3，如果想要在Windows下使用，请安装Perl语言环境，并且修改内部的mysqlbinlog为mysqlbinlog.exe（前提是mysqlbinlog.exe在环境变量内）。

> 特别注意：**MySQL Server一定要开启binlog，而且要开启binlog_format=row，因为只有row模式下，才会记录更新前后的数据，如果您用的是mixed模式，请到mixed分支，mixed模式下，不支持闪回**

我测试的Mysql数据库版本是5.7.25 理论上>=5.6的版本都支持。不过我没有做过测试

下面是安装步骤：

### 1、安装DBI/DBD

由于row模式下，记录了更新前后的数据，并且没有记录表的字段名，都是使用`@1`这样的占位符来代替字段名，所以，要还原原本的字段名必须通过mysql的`information_schema`这个库来获取对应表的字段。因此在脚本内，使用了Perl的DBI来操作数据库。

在CentOS7下面，关于安装`DBI/DBD::mysql`的方法有很多，有直接用yum安装的，也有下载源码安装的，不过有些我也没试过，下面是我本人安装的步骤。

```shell
1、通过yum安装cpan（cpan是Perl的一个包管理工具，类似nodejs的npm，python的pip）
yum -y install cpan
2、通过cpan安装DBI，如果是第一次使用cpan，会有一些配置的选项需要询问配置，此时，全部默认即可
cpan install DBI
3、通过cpan安装DBD:mysql
cpan install DBD::mysql
```

### 2、克隆项目并授权执行

```shell
1、克隆本项目到服务器本地
2、进入项目根目录并且授予可执行权限
cd bin2sql && chmod +x bin2sql
3、运行bin2sql
```

直接运行bin2sql会出现如下的帮助文档

```shell
MySQL Binlog to SQL
Options:
    -h, --host=name             Get the binlog from server, default localhost.
    -u, --user=name             Connect to the remote server as username, default root.
    -P, --port=#                Port number to use for connection or 3306 for default to.
    -p, --password[=name]       Password to connect to remote server.
    -t, --tables=name           Export tables in table names, delimiter by comma.
    -d, --database=name         List entries for just this database (local log only).
    -B, --flashback             Is print flashback SQL, only DML could be flashback.
    --start-datetime=name       Start reading the binlog at first event having a datetime
                                equal or posterior to the argument; the argument must be
                                a date and time in the local time zone, in any format
                                accepted by the MySQL server for DATETIME and TIMESTAMP
                                types, for example: 2004-12-25 11:25:56 (you should
                                probably use quotes for your shell to set it properly).

    --start-position=#          Start reading the binlog at position N. Applies to the
                                first binlog passed on the command line.

    --stop-datetime=name        Stop reading the binlog at first event having a datetime
                                equal or posterior to the argument; the argument must be
                                a date and time in the local time zone, in any format
                                accepted by the MySQL server for DATETIME and TIMESTAMP
                                types, for example: 2004-12-25 11:25:56 (you should
                                probably use quotes for your shell to set it properly).

    --stop-position=#           Stop reading the binlog at position N. Applies to the
                                last binlog passed on the command line.

    --only-dml                  Only print dml sql, optional, default disabled.
    --sql-type                  Sql type you want to process, support INSERT, UPDATE, DELETE.
    -f, --binlog=name           Read from binlog file.
    --help                      Print help message.
```

### 3、作者建议

如果数据库服务器有多台的话，建议在一台空的服务器运行本脚本，通过设定-h参数远程抓去binlog解析即可，不要随意放在数据库服务器上面运行，其原因有2

+ 不需要到处安装DBI和DBD这些Perl的数据库依赖
+ mysqlbinlog和bin2sql两个进程同时运行，对CPU有一定的消耗，可能会影响到数据库服务器的IO吞吐

## 用法和示例

###  1、用法选项

#### mysql相关连接配置

> 不管是获取schema信息还是mysqlbinlog获取binlog信息，都是使用同一套mysql的连接参数

```
-h host; -P port; -u user; -p password
这几个参数都是给mysqlbinlog使用的，这里强调一个参数，就是-u这个参数，必须拥有 REPLICATION SLAVE 权限。
建议授权如下
GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO User
```

#### 对象过滤

```
-d, --databases 解析目标db的sql，多个库用逗号隔开，如-d db1,db2。必选。

-t, --tables  解析目标table的sql，多张表用空格隔开，如-t tbl1 tbl2。可选。默认为空。

--only-dml 只解析dml，忽略ddl。可选。默认False。

--sql-type 解析指定类型，支持INSERT, UPDATE, DELETE。多个类型用逗号隔开，如--sql-type INSERT,DELETE。可选。默认为增删改都解析。
```

#### 范围解析

> 这里的参数都是配合mysqlbinlog使用的

```
-f,--binlog 要解析的Binlog文件名，无需全路径 。必须。

--start-position 起始解析位置。可选。

--stop-position 终止解析位置。可选。

--start-datetime 起始解析时间，格式'%Y-%m-%d %H:%M:%S'。可选。默认不过滤。

--stop-datetime 终止解析时间，格式'%Y-%m-%d %H:%M:%S'。可选。默认不过滤。
```

#### 闪回

```
-B, --flashback 生成回滚SQL，可选，默认为false，只有DML才支持闪回，DDL不支持闪回。
```



### 2、示例

#### 创建示例表

```sql
CREATE TABLE `user` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `username` varchar(255) DEFAULT NULL COMMENT '用户名',
  `address` varchar(255) DEFAULT NULL COMMENT '地址',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `phone_no` varchar(255) DEFAULT NULL COMMENT '电话号码',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 查看表原有数据

```sql
mysql> select * from user;
+----+-----------+-----------------+---------------------+--------------+
| id | username  | address         | create_time         | phone_no     |
+----+-----------+-----------------+---------------------+--------------+
|  1 | Succy     | 广西南宁市      | 2021-05-03 21:05:14 | 1300000001   |
|  2 | 王小花    | 山西太原市      | 2021-05-03 21:05:46 | 15099999999  |
|  3 | 江小白    | 重庆市          | 2021-05-03 21:06:21 | 19788888888  |
|  4 | 郭靖      | 湖北襄阳        | 2021-05-03 21:06:43 | 188888898999 |
|  5 | 杨过      | 江苏苏州        | 2021-05-03 21:07:10 | 16666666878  |
|  6 | 陆无双    | 山东济南市      | 2021-05-03 21:07:35 | 155236995454 |
+----+-----------+-----------------+---------------------+--------------+
6 rows in set (0.00 sec)
```

> 随机对数据进行修改，添加，删除，然后查询其binlog记录的sql。

#### 解析出user表所有操作的sql

```shell
shell> ./bin2sql -d demo -f mysql-bin.000002 -h 127.0.0.1 -t user

#210503 21:03:54 end_log_pos: 7852
CREATE TABLE `demo`.`user`  (
  `id` int(0) NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `username` varchar(255) NULL COMMENT '用户名',
  `address` varchar(255) NULL COMMENT '地址',
  `create_time` datetime(0) NULL COMMENT '创建时间',
  `phone_no` varchar(255) NULL COMMENT '电话号码',
  PRIMARY KEY (`id`)
);
#210503 21:05:24 end_log_pos: 8128
INSERT INTO `demo`.`user` VALUES(1, 'Succy', '广西南宁市', '2021-05-03 21:05:14', '1300000001');
#210503 21:05:53 end_log_pos: 8440
INSERT INTO `demo`.`user` VALUES(2, '王小花', '山西太原市', '2021-05-03 21:05:46', '15099999999');
#210503 21:06:27 end_log_pos: 8746
INSERT INTO `demo`.`user` VALUES(3, '江小白', '重庆市', '2021-05-03 21:06:21', '19788888888');
#210503 21:06:50 end_log_pos: 9053
INSERT INTO `demo`.`user` VALUES(4, '郭靖', '湖北襄阳', '2021-05-03 21:06:43', '188888898999');
#210503 21:07:14 end_log_pos: 9359
INSERT INTO `demo`.`user` VALUES(5, '杨过', '江苏苏州', '2021-05-03 21:07:10', '16666666878');
#210503 21:07:44 end_log_pos: 9672
INSERT INTO `demo`.`user` VALUES(6, '陆无双', '山东济南市', '2021-05-03 21:07:35', '155236995454');
#210503 21:10:45 end_log_pos: 10030
UPDATE `demo`.`user` SET `id`=5, `username`='杨过过', `address`='江苏南京市', `create_time`='2021-05-03 21:07:10', `phone_no`='16666666878' WHERE `id`=5 AND `username`='杨过' AND `address`='江苏苏州' AND `create_time`='2021-05-03 21:07:10' AND `phone_no`='16666666878';
#210503 21:11:07 end_log_pos: 10340
INSERT INTO `demo`.`user` VALUES(7, '公孙绿萼', '绝情谷', '2021-05-03 21:11:01', '188777738934');
#210503 21:11:30 end_log_pos: 10645
INSERT INTO `demo`.`user` VALUES(8, '程英', '桃花岛', '2021-05-03 21:11:24', '1778346836483');
#210503 21:11:33 end_log_pos: 10951
DELETE FROM `demo`.`user` WHERE `id`=3 AND `username`='江小白' AND `address`='重庆市' AND `create_time`='2021-05-03 21:06:21' AND `phone_no`='19788888888';
#210503 21:11:51 end_log_pos: 11315
UPDATE `demo`.`user` SET `id`=2, `username`='王小花', `address`='广东深圳市', `create_time`='2021-05-03 21:05:46', `phone_no`='15099999999' WHERE `id`=2 AND `username`='王小花' AND `address`='山西太原市' AND `create_time`='2021-05-03 21:05:46' AND `phone_no`='15099999999';
```

> 后面发现有些数据删错了，更新的也错了，想要把所有删除的和更新的数据恢复

#### 闪回所有误操作的数据

```shell
shell> ./bin2sql -d demo -f mysql-bin.000002 -h 127.0.0.1 -t user -B --sql-type DELETE,UPDATE
#210503 21:10:45 end_log_pos: 10030
UPDATE `demo`.`user` SET `id`=5, `username`='杨过', `address`='江苏苏州', `create_time`='2021-05-03 21:07:10', `phone_no`='16666666878' WHERE `id`=5 AND `username`='杨过过' AND `address`='江苏南京市' AND `create_time`='2021-05-03 21:07:10' AND `phone_no`='16666666878';
#210503 21:11:33 end_log_pos: 10951
INSERT INTO `demo`.`user` VALUES(3, '江小白', '重庆市', '2021-05-03 21:06:21', '19788888888');
#210503 21:11:51 end_log_pos: 11315
UPDATE `demo`.`user` SET `id`=2, `username`='王小花', `address`='山西太原市', `create_time`='2021-05-03 21:05:46', `phone_no`='15099999999' WHERE `id`=2 AND `username`='王小花' AND `address`='广东深圳市' AND `create_time`='2021-05-03 21:05:46' AND `phone_no`='15099999999';

```

**更多玩法等着你去发掘**

## 鸣谢

[binlog2sql](https://github.com/danfengcao/binlog2sql) 这个项目给我提供了我python版本的借鉴，虽然后面python版本的流产了。

[MySQL_Binlog_Table_Filter](https://github.com/sillydong/MySQL_Binlog_Table_Filter) 本工具借鉴了这个项目，由于我是Perl新手，这个项目给我提供了不少Perl相关写法借鉴。