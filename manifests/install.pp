# mesos::install class
# JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
# sudo dd if=/dev/zero of=/swapfile bs=64M count=16
# sudo mkswap /swapfile
# udo swapon /swapfile
# After compiling:
# sudo swapoff /swapfile
# sudo rm /swapfile
class mesos::install(
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
  $manage_firewall   = $mesos::manage_firewall
) inherits mesos{

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

  if $manage_user == true and !defined(User[$user]) and !defined(Group[$user]) and $user != 'root' {
    group { $user:
      ensure => present,
      name   => $user
    }
    user { $user:
      ensure     => present,
      managehome => true,
      shell      => '/sbin/nologin',
      require    => [Group[$user]],
      groups     => [$user]
    }
  } elsif  $manage_user == true and !defined(User[$user]) and $user == 'root' {
    user { $user:
      ensure     => present
    }
  }

  if $install_deps == true {

    $deps = $::operatingsystem?{
      centos => [
        'byacc',
        'cscope',
        'ctags',
        'diffstat',
        'doxygen',
        'elfutils',
        'flex',
        'gcc-gfortran',
        'indent',
        'intltool',
        'patchutils',
        'rcs',
        'redhat-rpm-config',
        'rpm-build',
        'rpm-sign',
        'swig',
        'systemtap',
        'python-devel',
        $java_package,
        "${java_package}-headless",
        "${java_package}-devel",
        'zlib-devel',
        'libcurl-devel',
        'openssl-devel',
        'cyrus-sasl-devel',
        'cyrus-sasl-md5',
        'apr-devel',
        'apr-util-devel',
        'subversion-devel',
        'wget',
        'git'
      ],
      default => fail('Operating system not supported.')
    }

    ensure_resource('package', $deps, { ensure => present })


    if !defined(Archive['libnl3']) {
      archive { 'libnl3':
        ensure           => present,
        url              => $libnlUrl,
        target           => $libnlSrcDir,
        follow_redirects => true,
        strip_components => 1,
        extension        => 'tar.gz',
        checksum         => false,
        src_target       => '/tmp'
      }
    }

    if !defined(File[$libnlSrcDir]) {
      file { $libnlSrcDir:
        ensure  => directory,
        path    => $libnlSrcDir,
        recurse => true,
        owner   => $user,
        mode    => 'u=rwxs,o=r',
        require => [
          Package['git'],
          User[$user],
          Archive['libnl3']
        ],
        notify  => [Exec['configure_libnl3']]
      }
    }

    if !defined(Exec['configure_libnl3']){
      exec { 'configure_libnl3':
        path        => [$::path, $libnlSrcDir],
        cwd         => $libnlSrcDir,
        command     => "./configure ${libnlConfigParams}",
        require     => [File[$libnlSrcDir]],
        refreshonly => true,
        notify      => [Exec['make_libnl3']]
      }
    }

    if !defined(Exec['make_libnl3']){
      exec { 'make_libnl3':
        path        => [$::path],
        cwd         => $libnlSrcDir,
        command     => "make -j${::processorcount}",
        require     => [Exec['configure_libnl3']],
        refreshonly => true,
        notify      => [Exec['make_libnl3_install']]
      }
    }

    if !defined(Exec['make_libnl3_install']){
      exec { 'make_libnl3_install':
        path        => [$::path],
        cwd         => $libnlSrcDir,
        require     => [Exec['make_libnl3']],
        refreshonly => true,
        command     => "make -j${::processorcount} install"
      }
    }

    if !defined(Archive['maven']) {
      archive { 'maven':
        ensure           => present,
        url              => $mvn_url,
        target           => $mvn_dir,
        follow_redirects => true,
        strip_components => 1,
        extension        => 'tar.gz',
        checksum         => false,
        src_target       => '/tmp'
      }
    }

    if !defined(File[$mvn_dir]) {
      file { $mvn_dir:
        ensure  => directory,
        owner   => $user,
        recurse => true,
        purge   => false,
        mode    => 'u=rwxs,o=r',
        require => [
          User[$user],
          Archive['maven']
        ]
      }
    }

    if !defined(File['/usr/bin/mvn']) {
      file { '/usr/bin/mvn':
        ensure  => link,
        target  => "${mvn_dir}/bin/mvn",
        require => [File[$mvn_dir]],
        notify  => [Vcsrepo[$sourceDir]]
      }
    }

    if $installDocker == true {
      if !defined(Class['docker']) {
        class { 'docker':
          dns          => $dockerDNS,
          socket_bind  => "unix:///${dockerSocketBind}",
          docker_users => [$user],
          socket_group => $user
        }
      }
    }
  }

  if !defined(Vcsrepo[$sourceDir]) {
    vcsrepo { $sourceDir:
      ensure   => $ensure,
      provider => 'git',
      source   => $url,
      revision => $branch,
      notify   => [File[$sourceDir]]
    }
  }

  $requirements = $network_isolation?{
    false   => [
      User[$user],
      Vcsrepo[$sourceDir]
    ],
    true    => [
      Exec['make_libnl3'],
      User[$user],
      Vcsrepo[$sourceDir]
    ],
    default => [
      User[$user],
      Vcsrepo[$sourceDir]
    ]
  }

  if !defined(File[$sourceDir]) {
    file { $sourceDir:
      ensure  => directory,
      path    => $sourceDir,
      recurse => true,
      owner   => $user,
      mode    => 'u=rwxs,o=r',
      require => $requirements,
      notify  => [Exec['bootstrap_mesos']]
    }
  }

  if !defined(Exec['bootstrap_mesos']) {
    exec { 'bootstrap_mesos':
      path        => [$::path, $sourceDir],
      cwd         => $sourceDir,
      timeout     => 0,
      command     => 'bootstrap',
      require     => [
        File[$sourceDir],
      ],
      refreshonly => true,
      notify      => [
        File["${sourceDir}/build"]
      ]
    }
  }

  if !defined(File["${sourceDir}/build"]) {
    file { "${sourceDir}/build":
      ensure  => directory,
      recurse => true,
      purge   => true,
      owner   => $user,
      mode    => 'u=rwxs,o=r',
      require => [Exec['bootstrap_mesos']]
    }
  }

  if !defined(Exec['configure_mesos']) {
    exec { 'configure_mesos':
      path        => [$::path, "${sourceDir}/build"],
      cwd         => "${sourceDir}/build",
      timeout     => 0,
      command     => "../configure ${mesosConfigParams}",
      refreshonly => true,
      require     => [File["${sourceDir}/build"]],
      notify      => [
        File["${sourceDir}/build"],
        Exec['make_mesos']
      ]
    }
  }


  if !defined(Exec['make_mesos']) {
    exec { 'make_mesos':
      path        => [$::path],
      cwd         => "${sourceDir}/build",
      timeout     => 0,
      command     => "make -j${::processorcount}",
      refreshonly => true,
      require     => [Exec['configure_mesos']],
      notify      => [
        File[$sourceDir],
        File["${sourceDir}/build"],
        Exec['make_install_mesos']
      ]
    }
  }

  if !defined(Exec['make_install_mesos']) {
    exec { 'make_install_mesos':
      path        => [$::path],
      cwd         => "${sourceDir}/build",
      timeout     => 0,
      refreshonly => true,
      command     => "make -j${::processorcount} install",
      require     => [
        Exec['make_mesos']
      ],
      notify      => [
        File[$sourceDir],
        File["${sourceDir}/build"]
      ]
    }
  }
}
