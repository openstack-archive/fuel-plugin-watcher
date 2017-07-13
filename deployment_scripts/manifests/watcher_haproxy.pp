notice('MODULAR: watcher/watcher_haproxy.pp')

$watcher_hash    = hiera_hash('watcher_plugin',{})
$public_ssl_hash = hiera_hash('public_ssl', {})
$ssl_hash        = hiera_hash('use_ssl', {})
$external_lb     = hiera('external_lb', false)

if (!$external_lb) {
  $public_ssl        = get_ssl_property($ssl_hash, $public_ssl_hash, 'watcher', 'public', 'usage', false)
  $public_ssl_path   = get_ssl_property($ssl_hash, $public_ssl_hash, 'watcher', 'public', 'path', [''])
  $internal_ssl      = get_ssl_property($ssl_hash, {}, 'watcher', 'internal', 'usage', false)
  $internal_ssl_path = get_ssl_property($ssl_hash, {}, 'watcher', 'internal', 'path', [''])

  $server_names        = $watcher_hash['watcher_nodes']
  $ipaddresses         = $watcher_hash['watcher_ipaddresses']
  $public_virtual_ip   = hiera('public_vip')
  $internal_virtual_ip = hiera('management_vip')

  Openstack::Ha::Haproxy_service {
    internal_virtual_ip => $internal_virtual_ip,
    ipaddresses         => $ipaddresses,
    public_virtual_ip   => $public_virtual_ip,
    server_names        => $server_names,
    public              => true,
  }

  openstack::ha::haproxy_service { 'watcher-api':
    order                  => '214',
    listen_port            => 9322,
    public_ssl             => $public_ssl,
    public_ssl_path        => $public_ssl_path,
    internal_ssl           => $internal_ssl,
    internal_ssl_path      => $internal_ssl_path,
    require_service        => 'watcher_api',
    haproxy_config_options => {
      'http-request' => 'set-header X-Forwarded-Proto https if { ssl_fc }',
    },
  }
}
