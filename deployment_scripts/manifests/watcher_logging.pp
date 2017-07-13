notice('MODULAR: watcher/watcher_logging.pp')

$content=':syslogtag, contains, "watcher" -/var/log/watcher-all.log
### stop further processing for the matched entries
& ~'

include ::rsyslog::params

::rsyslog::snippet { '57-watcher':
  content => $content,
}

Rsyslog::Snippet['57-watcher'] ~> Service[$::rsyslog::params::service_name]
