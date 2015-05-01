# mesos::slave::master resource
define mesos::resources::slave(
  $ensure            = $mesos::ensure,
  $url               = $mesos::url,
  $mvn_url           = $mesos::mvn_url,
  $libnlUrl          = $mesos::libnlUrl,
  $libnlSrcDir       = $mesos::libnlSrcDir,
  $libnlConfigParams = $mesos::libnlConfigParams,
  $mvn_dir           = $mesos::mvn_dir,
  $branch            = $mesos::branch,
  $sourceDir         = $mesos::sourceDir,
  $mesosConfigParams = $mesos::mesosConfigParams,
  $install_deps      = $mesos::install_deps,
  $java_package      = $mesos::java_package,
  $manage_user       = $mesos::manage_user,
  $user              = $mesos::user,
  $install_master    = $mesos::install_master,
  $masterServiceName = $mesos::masterServiceName,
  $masterLogDir      = $mesos::masterLogDir,
  $masterWorkDir     = $mesos::masterWorkDir,
  $install_slave     = $mesos::install_slave,
  $network_isolation = $mesos::network_isolation,
  $slaveServiceName  = $mesos::slaveServiceName,
  $slaveLogDir       = $mesos::slaveLogDir,
  $slaveWorkDir      = $mesos::slaveWorkDir,
  $masterOptions     = $mesos::masterOptions,
  $slaveOptions      = $mesos::slaveOptions,
  $installDocker     = $mesos::installDocker,
  $dockerVersion     = $mesos::dockerVersion,
  $dockerDNS         = $mesos::dockerDNS,
  $dockerSocketBind  = $mesos::dockerSocketBind,
  $manage_firewall   = $mesos::manage_firewall,
  $force_install     = $mesos::force_install
) {

  validate_string($url,$mvn_url,$libnlUrl,$libnlConfigParams,$branch,$java_package,$masterServiceName,$slaveServiceName,$dockerVersion,$dockerDNS,$mesosConfigParams)
  validate_absolute_path($sourceDir, $masterLogDir,$masterWorkDir,$slaveLogDir,$slaveWorkDir, $libnlSrcDir,$dockerSocketBind)
  validate_bool($manage_user,$install_deps,$install_master,$install_slave,$installDocker, $manage_firewall, $network_isolation, $force_install)
  validate_hash($masterOptions,$slaveOptions)


  if $slaveOptions != undef and $slaveOptions['IP'] != undef {
    if  !has_interface_with('ipaddress', $slaveOptions['IP']) {
      fail('The specified IP does not belong to this host.')
    }
  }

  if $masterOptions != undef and $masterOptions['IP'] != undef {
    if  !has_interface_with('ipaddress', $masterOptions['IP']) {
      fail('The specified does not belong to this host.')
    }
  }

  require mesos::install

  file { $slaveLogDir:
    ensure  => directory,
    recurse => true,
    purge   => true,
    owner   => $user,
    mode    => 'u=rwxs,o=r'
  }

  file { $slaveWorkDir:
    ensure  => directory,
    recurse => false,
    purge   => false,
    owner   => $user,
    mode    => 'u=rwxs,o=r'
  }

  if $manage_firewall == true and $slaveOptions['IP'] != undef and $slaveOptions['PORT'] != undef {
    if !defined(Class['firewalld2iptables']) {
      class { 'firewalld2iptables':
        manage_package   => true,
        iptables_ensure  => 'latest',
        iptables_enable  => true,
        ip6tables_enable => true
      }
    }

    if !defined(Class['firewall']) {
      class { 'firewall': }
    }

    if !defined(Service['firewalld']) {
      service { 'firewalld':
        ensure => 'stopped'
      }
    }

    firewall { "0_${slaveServiceName}_allow_incoming":
      port        => [$slaveOptions['PORT']],
      proto       => 'tcp',
      require     => [Class['firewall']],
      destination => $slaveOptions['IP'],
      action      => 'accept'
    }
  }

  file { "/usr/lib/systemd/system/${slaveServiceName}.service":
    ensure  => 'file',
    purge   => true,
    force   => true,
    notify  => [Exec["Reload_for_${slaveServiceName}"]],
    require => [
      File[$slaveLogDir],
      File[$slaveWorkDir]
    ],
    content => template('mesos/service/slave.service.erb'),
    owner   => $user,
    mode    => 'ug=rwxs,o=r'
  }

  service { $slaveServiceName:
    ensure   => 'running',
    provider => 'systemd',
    enable   => true,
    require  => [Exec["Reload_for_${slaveServiceName}"]]
  }

  exec{ "Purge_old_state_for_${slaveServiceName}":
    path    => [$::path],
    command => 'rm -f /var/lib/mesos-slave/meta/slaves/latest',
    notify  => [Exec["Reload_for_${slaveServiceName}"]],
    require => [File["/usr/lib/systemd/system/${masterServiceName}.service"]]
  }

  exec{ "Reload_for_${slaveServiceName}":
    path    => [$::path],
    command => 'systemctl daemon-reload',
    notify  => [Service[$slaveServiceName]],
    require => [
      File["/usr/lib/systemd/system/${slaveServiceName}.service"],
      Exec["Purge_old_state_for_${slaveServiceName}"]]
  }

}