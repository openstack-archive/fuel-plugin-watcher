notice('MODULAR: watcher/watcher.pp')

prepare_network_config(hiera_hash('network_scheme', {}))

$watcher_hash                = hiera_hash('watcher_plugin', {})
$watcher_plugins             = pick($watcher_hash['plugins'], {})
$rabbit_hash                 = hiera_hash('rabbit', {})
$neutron_config              = hiera_hash('neutron_config', {})
$public_ssl_hash             = hiera_hash('public_ssl', {})
$ssl_hash                    = hiera_hash('use_ssl', {})
$external_dns                = hiera_hash('external_dns', {})
$primary_watcher             = roles_include(['primary-watcher-node', 'primary-controller'])
$public_ip                   = hiera('public_vip')
$database_ip                 = hiera('database_vip')
$management_ip               = hiera('management_vip')
$region                      = hiera('region', 'RegionOne')
$use_neutron                 = hiera('use_neutron', false)
$service_endpoint            = hiera('service_endpoint')
$syslog_log_facility_watcher = hiera('syslog_log_facility_watcher')
$debug                       = pick($watcher_hash['debug'], hiera('debug', false))
$verbose                     = pick($watcher_hash['verbose'], hiera('verbose', true))
$default_log_levels          = hiera_hash('default_log_levels', {})
$use_syslog                  = hiera('use_syslog', true)
$use_stderr                  = hiera('use_stderr', false)
$rabbit_ha_queues            = hiera('rabbit_ha_queues', false)
$amqp_port                   = hiera('amqp_port')
$amqp_hosts                  = hiera('amqp_hosts')

$internal_auth_protocol = get_ssl_property($ssl_hash, {}, 'keystone', 'internal', 'protocol', 'http')
$internal_auth_address  = get_ssl_property($ssl_hash, {}, 'keystone', 'internal', 'hostname', [hiera('keystone_endpoint', ''), $service_endpoint, $management_ip])
$admin_auth_protocol    = get_ssl_property($ssl_hash, {}, 'keystone', 'admin', 'protocol', 'http')
$admin_auth_address     = get_ssl_property($ssl_hash, {}, 'keystone', 'admin', 'hostname', [hiera('keystone_endpoint', ''), $service_endpoint, $management_ip])
$api_bind_host          = get_network_role_property('management', 'ipaddr')

$region_name            = pick(hiera('region_name'), 'RegionOne')

$firewall_rule = '214 watcher-api'
$api_bind_port = '9322'

$watcher_user     = pick($watcher_hash['user'], 'watcher')
$watcher_password = $watcher_hash['user_password']

$mysql_hash          = hiera_hash('mysql', {})
$mysql_root_password = $mysql_hash['root_password']

$db_type     = 'mysql'
$db_user     = pick($watcher_hash['db_user'], 'watcher')
$db_name     = pick($watcher_hash['db_name'], 'watcher')
$db_password = pick($watcher_hash['root_password'], $mysql_root_password)
$db_host     = pick($watcher_hash['db_host'], $database_ip)
# LP#1526938 - python-mysqldb supports this, python-pymysql does not
if $::os_package_type == 'debian' {
  $extra_params = { 'charset' => 'utf8', 'read_timeout' => 60 }
} else {
  $extra_params = { 'charset' => 'utf8' }
}
$db_connection = os_database_connection({
  'dialect'  => $db_type,
  'host'     => $db_host,
  'database' => $db_name,
  'username' => $db_user,
  'password' => $db_password,
  'extra'    => $extra_params
})

notice($db_connection)

####### Disable upstart startup on install #######
tweaks::ubuntu_service_override { ['watcher-api', 'watcher-engine']:
  package_name => 'watcher',
}

include ::firewall
firewall { $firewall_rule :
  dport  => $api_bind_port,
  proto  => 'tcp',
  action => 'accept',
}

$nova_scheduler_default_filters = 'RetryFilter,AvailabilityZoneFilter,AggregateRamFilter,AggregateCoreFilter,DiskFilter,ComputeFilter,AggregateInstanceExtraSpecsFilter,ImagePropertiesFilter,ServerGroupAntiAffinityFilter,ServerGroupAffinityFilter,AggregateMetaDataIsolation'
$nova_ram_allocation_ratio = '1.5'
$nova_scheduler_driver = 'nova.scheduler.filter_scheduler.FilterScheduler'
$nova_disk_allocation_ratio = '1.0'
$nova_cpu_allocation_ratio = '8.0'
$nova_max_instances_per_host = '50'
$nova_scheduler_available_filters = 'nova.scheduler.filters.all_filters'

class { '::watcher' :
  ensure_package      => 'latest',
  database_connection => $db_connection,
  notification_driver => 'messagingv2',
  password            => $watcher_password,
  username            => $watcher_user,
  admin_user          => $watcher_user,
  admin_password      => $watcher_password,
  auth_uri            => "${internal_auth_protocol}://${internal_auth_address}:5000/",
  auth_url            => "${admin_auth_protocol}://${admin_auth_address}:35357/v3",
  identity_uri        => "${internal_auth_protocol}://${internal_auth_address}:35357/", 
  region_name         => $region_name,
  rabbit_os_host      => $amqp_hosts,
  rabbit_os_user      => $rabbit_hash['user'],
  rabbit_os_password  => $rabbit_hash['password'],
  rabbit_ha_queues    => true,
  nova_scheduler_default_filters => $nova_scheduler_default_filters,
  nova_ram_allocation_ratio => $nova_ram_allocation_ratio,
  nova_scheduler_driver => $nova_scheduler_driver,
  nova_disk_allocation_ratio => $nova_disk_allocation_ratio,
  nova_cpu_allocation_ratio =>$nova_cpu_allocation_ratio,
  nova_max_instances_per_host => $nova_max_instances_per_host,
  nova_scheduler_available_filters => $nova_scheduler_available_filters,
}

class { '::watcher::api':
  watcher_client_auth_uri => "${internal_auth_protocol}://${internal_auth_address}:5000/",
  watcher_client_auth_url => "${admin_auth_protocol}://${admin_auth_address}:35357/",
  watcher_client_username => $watcher_user,
  watcher_client_password => $watcher_password,
  watcher_api_bind_host   => $api_bind_host,
  watcher_api_port        => $api_bind_port,
  package_ensure          => 'latest',
  create_db_schema        => true,
  upgrade_db              => true
}

class { '::watcher::applier' :
  package_ensure      => 'latest',
}

class { '::watcher::decision_engine' :
  package_ensure      => 'latest',
  planner             => 'forced_order',
}

#class { '::watcher::policy': }

package { 'python-watcherclient':
  ensure => 'latest',
  tag    => ['openstack', 'watcher-package'],
}

Firewall[$firewall_rule] -> Class['watcher::api']
