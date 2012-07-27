# Fluent::Plugin::Irc

Fluent plugin to send messages to IRC server

## Installation

`$ fluent-gem install fluent-plugin-mongo`

## Configuration

### Example

```
<match **>
  type irc
  host localhost
  port 6667
  channel fluentd
  nick fluentd
  user fluentd
  real fluentd
  message notice: %s [%s] %s
  out_keys tag,time,msg
  time_key time
  time_format %Y/%m/%d %H:%M:%S
  tag_key tag
</match>
```

### Parameter

* host
  * IRC server host
* port
  * IRC server port number
* channel
  * channel to send messages (without first '#')
* nick
  * nickname registerd of IRC
* user
  * user name registerd of IRC
* real
  * real name registerd of IRC
* message
  * message format. %s will be replaced with value specified by out_keys
* out_keys
  * keys used to format messages
* time_key
  * key name for time
* time_format
  * time format. This will be formatted with Time#strftime.
* tag_key
  * key name for tag

## Copyright
* Copyright
  * Copyright (c) 2012 OKUNO Akihiro
* License
  * Apache License, Version 2.0
