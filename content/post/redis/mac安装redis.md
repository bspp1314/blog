---
title: "Mac安装redis"
date: 2020-10-10T17:06:12+08:00
draft: false
categories: ["redis"]
---

下载Redis

```
brew update
brew install redis
```

启动Redis

```
brew services start redis
```

停止Redis

```
brew services stop redis
```

配置Redis

```
redis-server /usr/local/etc/redis.conf
```

测试Redis是否同

```
redis-cli ping
```

If it replies “PONG”, then it’s good to go!

Location of Redis configuration file.

```
/usr/local/etc/redis.conf
```

Uninstall Redis and its files.

```
brew uninstall redis
rm ~/Library/LaunchAgents/homebrew.mxcl.redis.plist
```