notice('MODULAR: watcher/watcher_timezone.pp')

#TODO: customize timezone
exec {'moscow_timezone':
    command => '/usr/bin/timedatectl set-timezone Europe/Moscow'
}  ~> service { 'rsyslog': }
