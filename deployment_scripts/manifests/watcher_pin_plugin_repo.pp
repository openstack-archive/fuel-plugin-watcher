notice('MODULAR: watcher/watcher_pin_plugin_repo.pp')

$master_ip = pick(hiera('master_ip'), 'localhost')
$location  = "http://${master_ip}:8080/watcher"

apt::source { 'watcher':
  location => $location,
  release => 'mos9.0-watcher',
  repos => 'main',
}

apt::pin { 'watcher':
    release => 'mos9.0-watcher',
    priority => 1300,
}