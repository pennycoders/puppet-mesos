# Apache Mesos puppet module: #

1. __General introduction:__
    * __The reasoning behind this module:__ I have decided to create this module out of need for one of my own projects,
    due to lack of existing working modules. No module out there was enough for what I needed.
    * __Purpose:__ This modules intended use is to install and configure [Apache Mesos](http://mesos.apache.org).
    * __OS Support:__ This module has only been used and tested on [CentOS 7](http://www.centos.org/download/).

2. __Features:__
    * Installs all the [dependencies](http://mesos.apache.org/gettingstarted/) required to compile/build [Apache Mesos](http://mesos.apache.org):
         - byacc
         - cscope
         - ctags
         - diffstat
         - doxygen
         - elfutils
         - flex
         - gcc-gfortran
         - indent
         - intltool
         - patchutils
         - rcs
         - redhat-rpm-config
         - rpm-build
         - rpm-sign
         - swig
         - systemtap
         - pyhon-devel
         - java-openjdk (configurable, defaults to __java-1.8.0-openjdk__) - see __$java_package__ parameter for the main class.
         - java-openjdk-headless (configurable, defaults to __$java_package__-headless)
         - java-openjdk-devel (configurable, defaults to __$java_package__-devel)
         - apache maven (configurable, defaults to 3.3.1 - see manifests/init.pp and manifests/install.pp for more details ).
         - zlib-devel
         - libcurl-devel
         - openssl-devel
         - cyrus-sasl-devel
         - cyrus-sasl-md5
         - apr-devel
         - apr-util-devel
         - subversion-devel
         - wget
         - git
         - libnl3 (See http://www.infradead.org/~tgr/libnl/)
         - libnl3-devel See (http://www.infradead.org/~tgr/libnl/)
    * Configures, builds and install the desired [Apache Mesos](http://mesos.apache.org) version/branch/tag from github. 
    (configurable, defaults to 0.22.0). Please note that the configure/build parameters are also configurable.
    * Installs any desired __docker__ version, so you can have  all your micro-services/applications running
     securely inside containers (optional).
    * Optionally, it can set up default instances of Mesos master and slave as well as slaves (See __$install_master__ and __$install_slave__).

3. __Benefits:__
    * Highly flexible/configurable - EVERYTHING can be overridden.
    * Compatible with Hiera, so that you can store your configuration parameters in json, yaml or any other Hiera backend.
    * It is actually used in a production environment, so it's a must that it is maintained.
    * Offers unique features, and there are literally no peers for this module.
    * You can easily switch the mesos versions.
    * Offers good control.
    
## Included modules and classes: ##

* __Classes:__
    * __mesos__ - the main class
    * __mesos::install__ - the class that handles the installation - inherits all the parameters from the mesos classs
* __Resources:__
    * __mesos::resource::master__ - Handles the creation of a master service/instance and every configuration of it.
    * __mesos::resource::slave__ - Handles the creation of a mesos slave service/instance.
    
## Class & resource parameters roles: ##

* The __mesos__ _class_ parameters and default values:
```puppet
class mesos(
  # Whether to run git pull to ensure the specified mesos branch is always up to date.
  $ensure               = 'latest',
  # Mesos repository url - The url that the mesos git repository can be found at.
  $url                  = 'https://github.com/apache/mesos.git',
  # Maven archive url - The  url to fetch the desired maven binary from.
  $mvn_url              = 'http://mirrors.hostingromania.ro/apache.org/maven/maven-3/3.3.1/binaries/apache-maven-3.3.1-bin.tar.gz',
  # libnl source url  - The url to fetch libnl from
  $libnlUrl             = 'http://www.infradead.org/~tgr/libnl/files/libnl-3.2.25.tar.gz',
  # The temporary work directory to download libnl to
  $libnlSrcDir          = '/tmp/libnl3',
  # The flags to configure libnl3 with
  $libnlConfigParams    = '--prefix=/usr --sysconfdir=/etc --disable-static',
  # The path to install maven to
  $mvn_dir              = '/opt/maven',
  # Desired mesos version/branch
  $branch               = '0.22.0',
  # The mesos source directory -  The directory to which the mesos branch should be cloned
  $sourceDir            = '/opt/mesos',
  # The flags to configure mesos with - see http://mesos.apache.org/documentation/latest/configuration/
  $mesosConfigParams    = '--enable-optimize',
  # Whether the module should ensure the presence of the user and the group
  $manage_user          = true,
  # The owner of all the module-related files/resources/services
  $user                 = 'mesos',
  # Whether to install all the dependencies or not
  $install_deps         = true,
  # The jdk package name
  $java_package         = 'java-1.8.0-openjdk',
  # Whether to configure a default mesos master instance
  $install_master       = false,
  # The service name for the default master instance.
  $masterServiceName    = 'mesos-master',
  # The logs directory for the default mesos master instance
  $masterLogDir         = '/var/log/mesos-master',
  # The working directory for the default mesos master instance
  $masterWorkDir        = '/var/lib/mesos-master',
  # Whether or not to install a default slave instance
  $install_slave        = false,
  # Whether to install mesos with network isolation support
  $network_isolation    = false,
  # The service name for the default mesos slave instance
  $slaveServiceName     = 'mesos-slave',
  # The log directory for the default mesos slave instances
  $slaveLogDir          = '/var/log/mesos-slave',
  # The working directory for the default smesos slave instance
  $slaveWorkDir         = '/var/lib/mesos-slave',
  # The options for the default mesos master instance - See http://mesos.apache.org/documentation/latest/configuration/
  # Please note that the options need to be written with uppercase letters.
  $masterOptions        = hiera('mesosMasterConfig',{ }),
  # The options for the default mesos slave instance - See http://mesos.apache.org/documentation/latest/configuration/
  # Please note that the options need to be written with uppercase letters.
  $slaveOptions         = hiera('mesosSlaveConfig',{ }),
  # Whether to install docker or not
  $installDocker        = true,
  # The options which will be passed to the main docker class
  $dockerOptions        = hiera('classes::docker::options',{
    dns          => '8.8.8.8',
    socket_bind  => "unix:///var/run/docker.sock",
    docker_users => [$user],
    socket_group => $user
  }),
  # Whether or not to manage the firewall rules - Please note that by default, this module replaces firewalld with iptables
  $manage_firewall      = false,
  # Whether we the module should attempt to install Mesos forcefully.
  $force_install        = false
) {
```

* The __mesos::install__ _class_ and the default parameters
```puppet
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
  $manage_firewall   = $mesos::manage_firewall,
  $force_install     = $mesos::force_install
) inherits mesos{
```
* The __mesos::resource::master__ _resource_ and the default parameters
```puppet
define mesos::resources::master(
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
  $manage_firewall   = $mesos::manage_firewall,
  $force_install     = $mesos::force_install
) {
```

* The __mesos::resource::slave__ _resource_ and the default parameters
```puppet
define mesos::resources::master(
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
  $manage_firewall   = $mesos::manage_firewall,
  $force_install     = $mesos::force_install
) {
```
## In your attention: ##
    Regardless of the content of this documentation, you will still need to 
    examine the mesos documentation closely, as there might have been particularities which might have been emitted.