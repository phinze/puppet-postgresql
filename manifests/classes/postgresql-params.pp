class postgresql::params {

  $data_dir = $postgresql_data_dir ? {
    "" => "/var/lib/postgresql",
    default => $postgresql_data_dir,
  }
 
}
