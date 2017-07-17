# == Class: watcher::policy
#
# Configure the watcher policies
#
# === Parameters
#
# [*policies*]
#   (optional) Set of policies to configure for watcher
#   Example :
#     {
#       'watcher-context_is_admin' => {
#         'key' => 'context_is_admin',
#         'value' => 'true'
#       },
#       'watcher-default' => {
#         'key' => 'default',
#         'value' => 'rule:admin_or_owner'
#       }
#     }
#   Defaults to empty hash.
#
# [*policy_path*]
#   (optional) Path to the nova policy.json file
#   Defaults to /etc/watcher/policy.json
#
class watcher::policy (
  $policies    = {},
  $policy_path = '/etc/watcher/policy.json',
) {

  include ::watcher::deps

  validate_hash($policies)

  Openstacklib::Policy::Base {
    file_path => $policy_path,
  }

  create_resources('openstacklib::policy::base', $policies)


}
