include pget
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

  $suitecrmversion = '7.3.1 MAX'

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
      pget {'Download MSSQL Driver for PHP':
        source => 'http://download.microsoft.com/download/C/D/B/CDB0A3BB-600E-42ED-8D5E-E4630C905371/SQLSRV32.EXE',
        target => "${phppath}/ext",
      }

      # Unzip it (it's a self-extracting zip file)
      exec {'Unzip MSSQL Driver for PHP':
        name    => "cmd.exe /c \"${phppath}/ext/SQLSRV32.EXE /Q /T:\"${phppath}\\ext\" /C\"",
        path    => $::path,
        cwd     => $::system32,
        creates => "${phppath}/ext/php_sqlsrv_56_ts.dll",
        require => Pget['Download MSSQL Driver for PHP'],
      }

      # Modify php.ini. Use puppetlabs/ini instead?
      file_line {'Add SQL Driver to php.ini':
        path    => "${phppath}/php.ini",
        line    => 'extension=php_sqlsrv_56_ts.dll',
        require => Exec['Unzip MSSQL Driver for PHP'],
      }

      # Restart IIS
      exec {'Reset IIS':
        command => "cmd.exe /c \"iisreset\"",
        path    => $::path,
        cwd     => $::system32,
        require => File_line['Add SQL Driver to php.ini'],
      }

      # Download SuiteCRM
      pget {'Download SuiteCRM':
        source         => 'https://suitecrm.com/component/dropfiles/?task=frontfile.download&id=35',
        target         => $cache_dir,
        targetfilename => 'SuiteCRM.zip',
        require        => Exec['Reset IIS'],
      }

      # Uncompress it to c:\inetpub\wwwroot
      unzip {'Unzip SuiteCRM':
        name        => "${cache_dir}/SuiteCRM-${suitecrmversion}.zip",
        destination => 'C:/inetpub/wwwroot',
        creates     => "C:/inetpub/wwwroot/SuiteCRM-${suitecrmversion}/install.php",
        require     => Pget['Download SuiteCRM'],
      }

      # Delete SuiteCRM folder if it was previously installed
      file {'Delete SuiteCRM folder':
        ensure  => absent,
        path    => "C:/inetpub/wwwroot/SuiteCRM-${suitecrmversion}",
        recurse => true,
        purge   => true,
        force   => true,
        require => Unzip['Unzip SuiteCRM'],
      }

      # Rename dir to sugarcrm
      exec {'Rename web site folder':
        command  => "Rename-Item \"C:\\inetpub\\wwwroot\\SuiteCRM-${suitecrmversion}\" \"C:\\inetpub\\wwwroot\\sugarcrm\"",
        provider => powershell,
        require  => Unzip['Unzip SuiteCRM'],
      }

      # Give Write privileges to IUSR account. Permissions are inherited downstream to subfolders.
      acl {'C:\\inetpub\\wwwroot':
        permissions => [
          {identity => 'IIS_IUSRS', rights => ['read']},
          {identity => 'IUSR', rights => ['write']},
        ],
        require     => Unzip['Unzip SuiteCRM'],
      }

      # Create configuration file for SuiteCRM wizard.
      file {'C:\\inetpub\\wwwroot\\sugarcrm\\config_si.php':
        ensure  => present,
        content => template('suitecrm/config_si.php.erb'),
        require => Exec['Rename web site folder'],
      }

      # Create silent installation file.
      file {'C:\\inetpub\\wwwroot\\sugarcrm\\runSilentInstall.php':
        ensure  => present,
        content => template('suitecrm/runSilentInstall.php.erb'),
        require => Exec['Rename web site folder'],
      }

      # Call runSilentInstall.php
      exec {'Call runSilentInstall':
        command  => 'cmd /c "Start http://localhost/sugarcrm/runSilentInstall.php"',
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          File['C:\\inetpub\\wwwroot\\sugarcrm\\config_si.php'],
          File['C:\\inetpub\\wwwroot\\sugarcrm\\runSilentInstall.php'],
        ],
      }

    }
    default:
    {
      fail("Unsupported ensure \"${ensure}\"")
    }
  }
}