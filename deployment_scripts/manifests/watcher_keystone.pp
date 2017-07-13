notice('watcher PLUGIN: watcher_keystone.pp')

$watcher_hash      = hiera_hash('watcher_plugin', {})
$public_ip         = hiera('public_vip')
$management_ip     = hiera('management_vip')
$region            = hiera('region', 'RegionOne')
$public_ssl_hash   = hiera('public_ssl')
$ssl_hash          = hiera_hash('use_ssl', {})

$public_protocol   = get_ssl_property($ssl_hash, $public_ssl_hash, 'watcher', 'public', 'protocol', 'http')
$public_address    = get_ssl_property($ssl_hash, $public_ssl_hash, 'watcher', 'public', 'hostname', [$public_ip])
$internal_protocol = get_ssl_property($ssl_hash, {}, 'watcher', 'internal', 'protocol', 'http')
$internal_address  = get_ssl_property($ssl_hash, {}, 'watcher', 'internal', 'hostname', [$management_ip])
$admin_protocol    = get_ssl_property($ssl_hash, {}, 'watcher', 'admin', 'protocol', 'http')
$admin_address     = get_ssl_property($ssl_hash, {}, 'watcher', 'admin', 'hostname', [$management_ip])

$api_bind_port     = '9322'
$tenant            = pick($watcher_hash['tenant'], 'services')
$public_url        = "${public_protocol}://${public_address}:${api_bind_port}"
$internal_url      = "${internal_protocol}://${internal_address}:${api_bind_port}"
$admin_url         = "${admin_protocol}://${admin_address}:${api_bind_port}"

class {'::osnailyfacter::wait_for_keystone_backends':}
class { 'watcher::keystone::auth':
  password     => pick($watcher_hash['user_password'], 'watcher'),
  region       => $region,
  tenant       => $tenant,
  public_url   => $public_url,
  internal_url => $internal_url,
  admin_url    => $admin_url,
}

Class['::osnailyfacter::wait_for_keystone_backends'] -> Class['watcher::keystone::auth']
