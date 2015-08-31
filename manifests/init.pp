include wget
include unzip

# == Class: suitecrm
#
# Installs and configures SuiteCRM
#
# === Parameters
#
# [ensure]
#   installed. No other values are currently supported.
#
# [phppath]
#   Path to PHP files.
#
# === Examples
#
#  class {'suitecrm':
#   ensure  => installed,
#   phppath => 'C:/PHP',
#  }
#
# === Authors
#
# Pierrick Lozach <pierrick.lozach@inin.com>
#
# === Copyright
#
# Copyright 2015, Interactive Intelligence Inc.
#
class suitecrm (
  $ensure  = installed,
  $phppath = 'C:/PHP',
)
{

  # Define cache_dir
  $cache_dir = hiera('core::cache_dir', 'c:/users/vagrant/appdata/local/temp') # If I use c:/windows/temp then a circular dependency occurs when used with SQL
  if (!defined(File[$cache_dir]))
  {
    file {$cache_dir:
      ensure   => directory,
      provider => windows,
    }
  }

  case $ensure
  {
    installed:
    {
      # Download Microsoft SQL Server Driver for PHP
      wget::fetch {'Download MSSQL Driver for PHP':
        source      => 'http://download.microsoft.com/download/C/D/B/CDB0A3BB-600E-42ED-8D5E-E4630C905371/SQLSRV32.EXE',
        destination => "${phppath}/ext",
      }

      # Unzip it (it's a self-extracting zip file)
      unzip {'Unzip MSSQL Driver for PHP':
        name        => "${phppath}/ext/SQLSRV32.EXE",
        destination => "${phppath}/ext",
        require     => Wget::fetch['Download MSSQL Driver for PHP'],
      }

      # Modify php.ini
      file_line {'Add SQL Driver to php.ini':
        path    => "${phppath}/php.ini",
        line    => 'extension=php_sqlsrv_56_ts.dll',
        require => Unzip['Unzip MSSQL Driver for PHP'],
      }

      # Restart IIS
      exec {'Reset IIS':
        command => "cmd.exe /c \"iisreset\"",
        path    => $::path,
        cwd     => $::system32,
        require => File_line['Add SQL Driver to php.ini'],
      }

      # Download SuiteCRM
      wget::fetch {'Download SuiteCRM':
        source      => 'https://suitecrm.com/component/dropfiles/?task=frontfile.download&id=35',
        destination => ${cache_dir},
        require     => Exec['Reset IIS'],
      }

      # Uncompress it to c:\inetpub\wwwroot
      unzip {'Unzip SuiteCRM':
        name        => "${cache_dir}/SuiteCRM-7.3.1 MAX.zip",
        destination => "C:/inetpub/wwwroot",
        require     => Wget::fetch['Download SuiteCRM'],
      }

      # Give Write privileges to IUSR account. Permissions are inherited downstream to subfolders.
      acl {'C:/inetpub/wwwroot':
        permissions => [
          {identity => 'IIS_IUSRS', rights => ['read']},
          {identity => 'IUSR', rights => ['write']},
        ],
        require     => Unzip['Unzip SuiteCRM'],
      }

      # Create configuration file for SuiteCRM wizard. Can it be used for upgrades only?

    }
    default:
    {
      fail("Unsupported ensure \"${ensure}\"")
    }
  }
}