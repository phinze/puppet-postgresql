/*

==Definition: postgresql::user

Create a new PostgreSQL user

*/
define postgresql::user(
  $ensure=present, 
  $password=false, 
  $superuser=false,
  $createdb=false,
  $createrole=false,
  $hostname='/var/run/postgresql', 
  $port='5432', 
  $user='postgres') {

  $pgpass = $password ? {
    false   => "",
    default => "$password",
  }

  $superusertext = $superuser ? {
    false   => "NOSUPERUSER",
    default => "SUPERUSER",
  }

  $createdbtext = $createdb ? {
    false   => "NOCREATEDB",
    default => "CREATEDB",
  }

  $createroletext = $createrole ? {
    false   => "NOCREATEROLE",
    default => "CREATEROLE",
  }

  # Connection string
  $connection = "-h ${hostname} -p ${port} -U ${user}"

  # Script we use to manage postgresql users
  file { '/usr/local/sbin/pp-postgresql-user.sh':
    ensure => present,
    source => "puppet:///modules/${module_name}/pp-postgresql-user.sh",
    mode   => 0755,
  }

  case $ensure {
    present: {

      # The createuser command always prompts for the password.
      # User with '-' like www-data must be inside double quotes
      exec { "Create postgres user $name":
        command => $password ? {
          false => "/usr/local/sbin/pp-postgresql-user.sh '${connection}' createusernopwd '{name}'",
          default => "/usr/local/sbin/pp-postgresql-user.sh '${connection}' createuser '${name}' '${password}' ",
        },
        user    => "postgres",
        unless  => "/usr/local/sbin/pp-postgresql-user.sh '${connection}' checkuser '${name}'",
        require => Postgresql::Cluster["main"],
      }

      exec { "Set SUPERUSER attribute for postgres user $name":
        command => "psql ${connection} -c 'ALTER USER \"$name\" $superusertext' ",
        user    => "postgres",
        unless  => "/usr/local/sbin/pp-postgresql-user.sh '${connection}' checkuseropt '${name}' $superusertext rolsuper",
        require => Exec["Create postgres user $name"],
      }

      exec { "Set CREATEDB attribute for postgres user $name":
        command => "psql ${connection} -c 'ALTER USER \"$name\" $createdbtext' ",
        user    => "postgres",
        unless  => "psql ${connection} -tc \"SELECT rolcreatedb FROM pg_roles WHERE rolname = '$name'\" |grep -q $(echo $createdb |cut -c 1)",
        require => Exec["Create postgres user $name"],
      }

      exec { "Set CREATEROLE attribute for postgres user $name":
        command => "psql ${connection} -c 'ALTER USER \"$name\" $createroletext' ",
        user    => "postgres",
        unless  => "psql ${connection} -tc \"SELECT rolcreaterole FROM pg_roles WHERE rolname = '$name'\" |grep -q $(echo $createrole |cut -c 1)",
        require => Exec["Create postgres user $name"],
      }

      if $password {
        $host = $hostname ? {
          '/var/run/postgresql' => "localhost",
          default               => $hostname,
        }

        # change only if it's not the same password
        exec { "Change password for postgres user $name":
          command => "/usr/local/sbin/pp-postgresql-user.sh '${connection}' setpwd '${name}' '{$password}'",
          user    => "postgres",
          unless  => "/usr/local/sbin/pp-postgresql-user.sh '-h ${host} -p ${port} -U ${name}' checkpwd '${host}:${port}:template1:${name}:${pgpass}'",
          require => Exec["Create postgres user $name"],
        }
      }

    }

    absent:  {
      exec { "Remove postgres user $name":
        command => "psql ${connection} -c 'DROP USER \"$name\" ' ",
        user    => "postgres",
        onlyif  => "psql ${connection} -c '\\du' | grep '$name  *|'",
        require => Postgresql::Cluster["main"],
      }
    }

    default: {
      fail "Invalid 'ensure' value '$ensure' for postgres::user"
    }
  }
}
