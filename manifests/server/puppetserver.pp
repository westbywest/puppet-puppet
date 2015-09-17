# == Class: puppet::server::puppetserver
#
# Configures the puppetserver jvm configuration file using augeas.
#
# === Parameters:
#
# * `java_bin`
# Path to the java executable to use
#
# * `config`
# Path to the jvm configuration file.
# This file is usually either /etc/default/puppetserver or
# /etc/sysconfig/puppetserver depending on your *nix flavor.
#
# * `jvm_min_heap_size`
# Translates into the -Xms option and is added to the JAVA_ARGS
#
# * `jvm_max_heap_size`
# Translates into the -Xmx option and is added to the JAVA_ARGS
#
# * `jvm_extra_args`
# Custom options to pass through to the java binary. These get added to
# the end of the JAVA_ARGS variable
#
#
# === Example
#
# @example
#
#   # configure memory for java < 8
#   class {'::puppet::server::puppetserver':
#     jvm_min_heap_size => '1G',
#     jvm_max_heap_size => '3G',
#     jvm_extra_args    => '-XX:MaxPermSize=256m',
#   }
#
class puppet::server::puppetserver (
  $java_bin          = $::puppet::server_jvm_java_bin,
  $config            = $::puppet::server_jvm_config,
  $dir               = $::puppet::server_jvm_dir,
  $server_ca         = $::puppet::server_ca,
  $ssl_cert          = $::puppet::server::ssl_cert,
  $ssl_cert_key      = $::puppet::server::ssl_cert_key,
  $ssl_ca_cert       = $::puppet::server::ssl_ca_cert,
  $jvm_min_heap_size = $::puppet::server_jvm_min_heap_size,
  $jvm_max_heap_size = $::puppet::server_jvm_max_heap_size,
  $jvm_extra_args    = $::puppet::server_jvm_extra_args,
) {

  $puppetserver_package = pick($::puppet::server_package, 'puppetserver')

  $jvm_cmd_arr = ["-Xms${jvm_min_heap_size}", "-Xmx${jvm_max_heap_size}", $jvm_extra_args]
  $jvm_cmd = strip(join(flatten($jvm_cmd_arr),' '))

  augeas {'puppet::server::puppetserver::jvm':
    lens    => 'Shellvars.lns',
    incl    => $config,
    context => "/files${config}",
    changes => [
      "set JAVA_ARGS '\"${jvm_cmd}\"'",
      "set JAVA_BIN ${java_bin}",
    ],
  }

  # JVM puppetserver doesn't respect 'ca' parameter in puppet.conf, only in bootstrap.cfg
  $puppetserver_ca_enabled_ensure = $server_ca ? {
    true => 'present',
    default => 'absent',
  }
  $puppetserver_ca_disabled_ensure = $server_ca ? {
    true => 'absent',
    default => 'present',
  }
  file_line { 'puppetserver_bootstrap.cfg_ca_enabled':
    path => "${dir}/bootstrap.cfg",
    ensure => $puppetserver_ca_enabled_ensure,
    line => 'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
  }
  file_line { 'puppetserver_bootstrap.cfg_ca_disabled':
    path => "${dir}/bootstrap.cfg",
    ensure => $puppetserver_ca_disabled_ensure,
    line => 'puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service',
  }

  # If we are not CA, specify ssl-key, ssl-cert, ssl-ca-cert for Jetty.
  # The chaining works around https://tickets.puppetlabs.com/browse/MODULES-1880
  if (! $server_ca) {
    file_line { 'Add ssl cert':
      path => "${dir}/conf.d/webserver.conf",
      line => " ssl-cert = ${ssl_cert}",
      after => '^.*ssl-port =.*',
    } ->
    file_line { 'Add ssl key':
      path => "${dir}/conf.d/webserver.conf",
      line => " ssl-key = ${ssl_cert_key}",
      after => '^.*ssl-cert =.*',
    } ->
    file_line { 'Add ssl ca-cert':
      path => "${dir}/conf.d/webserver.conf",
      line => " ssl-ca-cert = ${ssl_ca_cert}",
      after => '^.*ssl-key =.*',
    }
  }
}
