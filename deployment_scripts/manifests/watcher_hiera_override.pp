notice('MODULAR: watcher/watcher_hiera_override.pp')

$watcher_plugin = hiera('fuel-plugin-watcher', undef)
$hiera_dir = '/etc/hiera/plugins'
$plugin_name = 'fuel-plugin-watcher'
$plugin_yaml = "${plugin_name}.yaml"

if $watcher_plugin {
  $network_metadata    = hiera_hash('network_metadata')
  $watcher_base_hash   = hiera_hash('watcher', {})
  $user_password       = $watcher_plugin['user_password']
  $watcher_role_exists = empty(nodes_with_roles(['primary-watcher-node'])) ? {
    true    => false,
    default => true,
  }
  if $watcher_role_exists {
    $watcher_nodes       = get_nodes_hash_by_roles($network_metadata, ['primary-watcher-node', 'watcher-node'])
    $watcher_address_map = get_node_to_ipaddr_map_by_network_role($watcher_nodes, 'management')
    $watcher_nodes_ips   = values($watcher_address_map)
    $watcher_nodes_names = keys($watcher_address_map)
  } else {
    $watcher_nodes       = get_nodes_hash_by_roles($network_metadata, ['primary-controller', 'controller'])
    $watcher_address_map = get_node_to_ipaddr_map_by_network_role($watcher_nodes, 'management')
    $watcher_nodes_ips   = values($watcher_address_map)
    $watcher_nodes_names = keys($watcher_address_map)
  }

  $syslog_log_facility_watcher = hiera('syslog_log_facility_watcher', 'LOG_LOCAL0')
  $default_log_levels         = hiera('default_log_levels')

  ###################
  $calculated_content = inline_template('
watcher_plugin:
  user_password: <%= @user_password %>
  watcher_standalone: <%= @watcher_role_exists %>
  watcher_ipaddresses:
<%
@watcher_nodes_ips.each do |watcherip|
%>    - <%= watcherip %>
<% end -%>
  watcher_nodes:
<%
@watcher_nodes_names.each do |watchername|
%>    - <%= watchername %>
<% end -%>
syslog_log_facility_watcher: <%= @syslog_log_facility_watcher %>
"watcher::logging::default_log_levels":
<%
@default_log_levels.each do |k,v|
%>  <%= k %>: <%= v %>
<% end -%>
')

  ###################
  file {'/etc/hiera/override':
    ensure  => directory,
  } ->
  file { "${hiera_dir}/${plugin_yaml}":
    ensure  => file,
    content => "${calculated_content}",
  }

  package {'ruby-deep-merge':
    ensure  => 'installed',
  }
}
