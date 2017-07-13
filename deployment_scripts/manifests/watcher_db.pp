notice('MODULAR: watcher/watcher_db.pp')

$watcher_hash    = hiera_hash('watcher_plugin', {})
$mysql_hash     = hiera_hash('mysql', {})
$management_vip = hiera('management_vip', undef)
$database_vip   = hiera('database_vip')

$mysql_root_user     = pick($mysql_hash['root_user'], 'root')
$mysql_db_create     = pick($mysql_hash['db_create'], true)
$mysql_root_password = $mysql_hash['root_password']

$db_user     = pick($watcher_hash['db_user'], 'watcher')
$db_name     = pick($watcher_hash['db_name'], 'watcher')
$db_password = pick($watcher_hash['db_password'], $mysql_root_password)

$db_host          = pick($watcher_hash['db_host'], $database_vip)
$db_create        = pick($watcher_hash['db_create'], $mysql_db_create)
$db_root_user     = pick($watcher_hash['root_user'], $mysql_root_user)
$db_root_password = pick($watcher_hash['root_password'], $mysql_root_password)

$allowed_hosts = [ 'localhost', '127.0.0.1', '%' ]

class { '::openstack::galera::client':
  custom_setup_class => hiera('mysql_custom_setup_class', 'galera'),
}

class { 'watcher::db::mysql':
  user          => $db_user,
  password      => $db_password,
  dbname        => $db_name,
  allowed_hosts => $allowed_hosts,
}

class { 'osnailyfacter::mysql_access':
  db_host     => $db_host,
  db_user     => $db_root_user,
  db_password => $db_root_password,
}

Class['openstack::galera::client'] ->
  Class['osnailyfacter::mysql_access'] ->
    Class['watcher::db::mysql']

class mysql::server {}
include mysql::server