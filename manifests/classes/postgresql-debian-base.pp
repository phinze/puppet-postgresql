/*

==Class: postgresql::debian::base

This class is dedicated to the common parts 
shared by the different flavors of Debian

*/
class postgresql::debian::base inherits postgresql::base {

  include postgresql::params

  Package["postgresql"] {
    name   => "postgresql-${version}",
    notify => Exec["drop initial cluster"],
  }

  package {[
    "libpq-dev",
    "libpq5",
    "postgresql-client-${version}",
    "postgresql-common",
    "postgresql-client-common",
    "postgresql-contrib-${version}"
    ]:
    ensure  => present,
    require => Package["postgresql"],
  }

  exec {"drop initial cluster":
    command     => "pg_dropcluster --stop ${version} main",
    refreshonly => true,
    onlyif      => "test \$(su -c \"psql -tA -c 'SELECT count(*)=3 FROM pg_catalog.pg_database;'\" postgres) = t",
    timeout     => 60,
  }

  
  postgresql::cluster {"main":
    ensure      => present,
    clustername => "main",
    version     => $version,
    encoding    => "UTF8",
    data_dir    => "${postgresql::params::data_dir}",
    require     => [Package["postgresql"], Exec["drop initial cluster"]],
  }
  
}
