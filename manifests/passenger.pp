# Class: dashboard::passenger
#
# This class configures parameters for the puppet-dashboard module.
#
# Parameters:
#   [*dashboard_site*]
#     - The ServerName setting for Apache
#
#   [*dashboard_port*]
#     - The port on which puppet-dashboard should run
#
#   [*dashboard_config*]
#     - The Dashboard configuration file
#
#   [*dashboard_root*]
#     - The path to the Puppet Dashboard library
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class dashboard::passenger (
  $dashboard_site,
  $dashboard_port,
  $dashboard_config,
  $dashboard_root,
  $passwords_template,
  $ssl_enabled,
  $ssl_cert,
  $ssl_key
) inherits dashboard {

  require ::passenger
  include apache

  file { '/etc/init.d/puppet-dashboard':
    ensure => absent,
  }

  file { 'dashboard_config':
    ensure => absent,
    path   => $dashboard_config,
  }

  if $passwords_template {
    $passwords_file = "${apache::passwords_dir}/dashboard_passenger"
    file { 'apache_passwords':
      ensure => present,
      path   => $passwords_file,
      content => template($passwords_template),
      before  => Apache::Vhost[$dashboard_site]
    }
  }

  if $ssl_enabled {
    file { "dashboard_ssl_cert":
      ensure  => file,
      path    => "${apache::ssl_certs_dir}/dashboard_ssl_cert",
      source  => "puppet:///${ssl_cert}",
      owner   => "root",
      group   => "root",
      mode    => 0755
    }

    file { "dashboard_ssl_key":
      ensure => file,
      path    => "${apache::ssl_certs_dir}/dashboard_ssl_key",
      source  => "puppet:///${ssl_key}",
      owner   => "root",
      group   => "root",
      mode    => 0755
    }

    apache::vhost { $dashboard_site:
      port            => $dashboard_port,
      priority        => '1',
      rewrite_cond    => '%{HTTPS} off',
      rewrite_rule    => '(.*) https://%{HTTPS_HOST}%{REQUEST_URI}',
    }

    apache::vhost { $dashboard_site:
      port            => $dashboard_ssl_port,
      priority        => '2',
      docroot         => "${dashboard_root}/public",
      custom_fragment => $passwords_template ? {
        undef   => undef,
        default => template('dashboard/apache_auth_frag.erb')
      },
      ssl             => true,
      ssl_cert        => "${apache::ssl_certs_dir}/dashboard_ssl_cert",
      ssl_key         => "${apache::ssl_certs_dir}/dashboard_ssl_key",
      require         => [File["dashboard_ssl_cert"],File["dashboard_ssl_key"]]
    }
  } else {
    apache::vhost { $dashboard_site:
      port            => $dashboard_port,
      priority        => '1',
      docroot         => "${dashboard_root}/public",
      custom_fragment => $passwords_template ? {
        undef   => undef,
        default => template('dashboard/apache_auth_frag.erb')
      }
    }
  }
}
