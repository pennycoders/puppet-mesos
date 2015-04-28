# Class: mesos
#
# This module manages mesos
#
# Parameters: none
#
# Actions:
#
# Requires: see Modulefile
#
# Sample Usage:
# class {'mesos':
#   ensure => present,
#   install_deps = true,
# }
#
class mesos(
  $ensure               = 'latest',
  $url                  = 'https://github.com/apache/mesos.git',
  $mvn_url              = 'http://mirrors.hostingromania.ro/apache.org/maven/maven-3/3.3.1/binaries/apache-maven-3.3.1-bin.tar.gz',
  $libnlUrl             = 'http://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz',
  $libnlSrcDir          = '/tmp/libnl3',
  $libnlConfigParams    = '--prefix=/usr --sysconfdir=/etc --disable-static',
  $mvn_dir              = '/opt/maven',
  $branch               = '0.22.0',
  $sourceDir            = '/opt/mesos',
  $mesosConfigParams    = '--enable-optimize',
  $manage_user          = true,
  $user                 = 'mesos',
  $install_deps         = true,
  $java_package         = 'java-1.8.0-openjdk',
  $install_master       = false,
  $masterServiceName    = 'mesos-master',
  $masterLogDir         = '/var/log/mesos-master',
  $masterWorkDir        = '/var/lib/mesos-master',
  $install_slave        = false,
  $network_isolation    = false,
  $slaveServiceName     = 'mesos-slave',
  $slaveLogDir          = '/var/log/mesos-slave',
  $slaveWorkDir         = '/var/lib/mesos-slave',
  $masterOptions        = hiera('mesosMasterConfig',{ }),
  $slaveOptions         = hiera('mesosSlaveConfig',{ }),
  $installDocker        = true,
  $dockerVersion        = 'latest',
  $dockerDNS            = '8.8.8.8',
  $dockerSocketBind     = '/var/run/docker.sock',
  $manage_firewall      = false
) {


  validate_string($url,$mvn_url,$libnlUrl,$libnlConfigParams,$branch,$java_package,$masterServiceName,$slaveServiceName,$dockerVersion,$dockerDNS,$mesosConfigParams)
  validate_absolute_path($sourceDir, $masterLogDir,$masterWorkDir,$slaveLogDir,$slaveWorkDir, $libnlSrcDir,$dockerSocketBind)
  validate_bool($manage_user,$install_deps,$install_master,$install_slave,$installDocker, $manage_firewall, $network_isolation)
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

  anchor { 'mesos:install:start': } ->
  class { 'mesos::install': }->
  anchor { 'mesos:install:end': }

  if($install_master == true) {
    anchor { 'mesos:master:start': }
    mesos::resources::master{ "${::fqdn}": } ->
    anchor { 'mesos:master:end': }
  }

  if($install_slave == true) {
    anchor { 'mesos:slave:start': }
    mesos::resources::slave{ "${::fqdn}": }->
    anchor{ 'mesos:slave:end': }
  }
}
