include pget

# == Define: php::unzip
#
# Extracts a ZIP archive on a Windows system.
#
# === Parameters
#
# [*destination*]
#  Required, the destination directory to extract the files into.
#
# [*creates*]
#  The `creates` parameter for the exec resource that extracts the ZIP file,
#  default is undefined.
#
# [*refreshonly*]
#  The `refreshonly` parameter for the exec resource that extracts the ZIP file,
#  defaults to false.
#
# [*unless*]
#  The `unless` parameter for the exec resource that extracts the ZIP file,
#  default is undefined.
#
# [*zipfile*]
#  The path to the ZIP file to extract, defaults the name of the resource.
#
# [*provider*]
#  Advanced parameter, sets the provider for the exec resource that extracts
#  the ZIP file, defaults to 'powershell'.
#
#  http://msdn.microsoft.com/en-us/library/windows/desktop/bb787866.
#
#  Defaults to 20, which is sum of:
#   * 4:  Do not display a progress dialog box.
#   * 16: Respond with "Yes to All" for any dialog box that is displayed.
#
# [*command_template*]
#  Advanced paramter for generating PowerShell that extracts the ZIP file,
#  defaults to 'windows/unzip.ps1.erb'.
#
# [*timeout*]
# Execution timeout in seconds for the unzip command; 0 disables timeout,
# defaults to 300 seconds (5 minutes).
#
define scrm::unzip(
  $destination,
  $creates          = undef,
  $refreshonly      = false,
  $unless           = undef,
  $zipfile          = $name,
  $provider         = 'powershell',
  $command_template = 'scrm/unzip.ps1.erb',
  $timeout          = 300,
) {
  validate_absolute_path($destination)

  if (! $creates and ! $refreshonly and ! $unless){
    fail("Must set one of creates, refreshonly, or unless parameters.\n")
  }

  exec { "unzip-${name}":
    command     => template($command_template),
    creates     => $creates,
    refreshonly => $refreshonly,
    unless      => $unless,
    provider    => $provider,
    timeout     => $timeout,
  }
}

# == Class: scrm
#
# Installs and configures SugarCRM or SuiteCRM
#
# === Parameters
#
# [ensure]
#   installed. No other values are currently supported.
#
# [phppath]
#   Path to PHP files.
#
# [crm]
#   suitecrm or sugarcrm. At this time, suitecrm is not implemented yet due to an issue with the zip file containing duplicates.
#
# [inintoolbar]
#   installed or none.
#
# === Examples
#
#  class {'scrm':
#   ensure      => installed,
#   phppath     => 'C:/PHP',
#   crm         => 'sugarcrm',
#   inintoolbar => installed,
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
class scrm (
  $ensure      = installed,
  $phppath     = 'C:/PHP',
  $crm         = 'sugarcrm',
  $inintoolbar = installed,
)
{

  $suitecrmversion = '7.3.1-MAX'

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
      # Download Microsoft SQL Server Driver for PHP (unofficial x64 version)
      pget {'Download MSSQL Driver for PHP':
        source => 'https://www.dropbox.com/s/657xa03lsb2ycfa/sqlsrv_unofficial_3.0.2.2.zip?dl=1',
        target => "${phppath}/ext",
      }

      # Unzip it
      scrm::unzip {"${phppath}/ext/sqlsrv_unofficial_3.0.2.2.zip":
        destination => "${phppath}/ext",
        creates     => "${phppath}/ext/x64/php_sqlsrv_56_nts.dll",
        require     => Pget['Download MSSQL Driver for PHP'],
      }

      # Copy x64 PHP for MSSQL driver to /ext
      exec {'Copy PHP SQL Driver':
        command  => "Copy-Item \"${phppath}\\ext\\x64\\php_sqlsrv_56_nts.dll\" \"${phppath}\\ext\"",
        provider => powershell,
        require  => Scrm::Unzip["${phppath}/ext/sqlsrv_unofficial_3.0.2.2.zip"],
      }

      # Copy x64 PHP for MSSQL PDO driver to /ext
      exec {'Copy PHP SQL PDO Driver':
        command  => "Copy-Item \"${phppath}\\ext\\x64\\php_pdo_sqlsrv_56_nts.dll\" \"${phppath}\\ext\"",
        provider => powershell,
        require  => Scrm::Unzip["${phppath}/ext/sqlsrv_unofficial_3.0.2.2.zip"],
      }

      # Add SQL Driver to php.ini
      file_line {'Add SQL Driver to php.ini':
        path    => "${phppath}/php.ini",
        line    => 'extension=php_sqlsrv_56_nts.dll',
        require => Exec['Copy PHP SQL Driver'],
      }

      # Add SQL PDO Driver to php.ini
      file_line {'Add SQL PDO Driver to php.ini':
        path    => "${phppath}/php.ini",
        line    => 'extension=php_pdo_sqlsrv_56_nts.dll',
        require => Exec['Copy PHP SQL PDO Driver'],
      }

      # Restart IIS
      exec {'Reset IIS':
        command => "cmd.exe /c \"iisreset\"",
        path    => $::path,
        cwd     => $::system32,
        require => [
          File_line['Add SQL Driver to php.ini'],
          File_line['Add SQL PDO Driver to php.ini'],
        ],
      }

      # Delete CRM folder if it's there
      file {'Delete CRM folder':
        ensure  => absent,
        path    => 'C:/inetpub/wwwroot/crm',
        recurse => true,
        purge   => true,
        force   => true,
      }

      # Start SQL Browser service
      service {'sql-browser-service-start':
        ensure => running,
        enable => true,
        name   => 'SQLBrowser',
      }

      case $crm
      {
        suitecrm:
        {
          # Download SuiteCRM
          pget {'Download SuiteCRM':
            source         => 'https://suitecrm.com/component/dropfiles/?task=frontfile.download&id=35',
            target         => $cache_dir,
            targetfilename => 'SuiteCRM.zip',
            require        => [
              File['Delete CRM folder'],
              Exec['Reset IIS'],
            ],
          }

          # Delete SuiteCRM folder if it was previously installed
          file {'Delete SuiteCRM folder':
            ensure  => absent,
            path    => "C:/inetpub/wwwroot/SuiteCRM-${suitecrmversion}",
            recurse => true,
            purge   => true,
            force   => true,
            require => PGet['Download SuiteCRM'],
          }

          # Unzip to C:\inetpub\wwwroot\SuiteCRM-<version>\
          scrm::unzip {"${cache_dir}/SuiteCRM.zip":
            destination => 'C:/inetpub/wwwroot',
            creates     => "C:/inetpub/wwwroot/SuiteCRM-${suitecrmversion}/install.php",
            require     => File['Delete SuiteCRM folder'],
          }

          # Rename dir to crm
          exec {'Rename web site folder':
            command  => "Rename-Item \"C:\\inetpub\\wwwroot\\SuiteCRM-${suitecrmversion}\" \"C:\\inetpub\\wwwroot\\crm\"",
            provider => powershell,
            require  => Scrm::Unzip["${cache_dir}/SuiteCRM.zip"],
          }
        }
        sugarcrm:
        {
          # Download SugarmCRM
          pget {'Download SugarCRM':
            source         => 'http://freefr.dl.sourceforge.net/project/sugarcrm/1%20-%20SugarCRM%206.5.X/SugarCommunityEdition-6.5.X/SugarCE-6.5.22.zip',
            target         => $cache_dir,
            targetfilename => 'SugarCE-6.5.22.zip',
            require        => [
              Exec['Reset IIS'],
            ],
          }

          # Unzip to C:\inetpub\wwwroot\SugarCRM\
          scrm::unzip {"${cache_dir}/SugarCE-6.5.22.zip":
            destination => 'C:/inetpub/wwwroot',
            creates     => 'C:/inetpub/wwwroot/SugarCE-Full-6.5.22/install.php',
            require     => Pget['Download SugarCRM'],
          }

          # Rename dir to crm
          exec {'Rename web site folder':
            command  => "Rename-Item \"C:\\inetpub\\wwwroot\\SugarCE-Full-6.5.22\" \"C:\\inetpub\\wwwroot\\crm\"",
            provider => powershell,
            require  => [
              File['Delete CRM folder'],
              Scrm::Unzip["${cache_dir}/SugarCE-6.5.22.zip"],
            ],
          }
        }
        default:
        {
          fail("Unsupported crm \"${crm}\"")
        }
      }

      # Give Write privileges to IUSR account. Permissions are inherited downstream to subfolders.
      acl {'C:\\inetpub\\wwwroot':
        permissions => [
          {identity => 'IIS_IUSRS', rights => ['read']},
          {identity => 'IUSR',      rights => ['write']},
        ],
        require     => Exec['Rename web site folder'],
      }

      # Create configuration file for CRM wizard.
      file {'C:\\inetpub\\wwwroot\\crm\\config_si.php':
        ensure  => present,
        content => template('scrm/config_si.php.erb'),
        require => Exec['Rename web site folder'],
      }

      # Create silent installation file.
      file {'C:\\inetpub\\wwwroot\\crm\\runSilentInstall.php':
        ensure  => present,
        content => template('scrm/runSilentInstall.php.erb'),
        require => Exec['Rename web site folder'],
      }

      # Call runSilentInstall.php
      exec {'Call runSilentInstall':
        command  => 'cmd /c "Start http://localhost/crm/install.php"',
        path     => $::path,
        cwd      => $::system32,
        provider => windows,
        require  => [
          File['C:\\inetpub\\wwwroot\\crm\\config_si.php'],
          File['C:\\inetpub\\wwwroot\\crm\\runSilentInstall.php'],
        ],
      }

      case $inintoolbar
      {
        installed:
        {
          vcsrepo {"${cache_dir}/inin-toolbar":
            ensure   => present,
            provider => 'git',
            source   => 'https://PierrickI3@bitbucket.org/laurentmillan/sugarcrm-toolbar.git',
          }

          # Backup old header.tpl
          exec {'Backup old header.tpl':
            command  => "Rename-Item \"C:\\inetpub\\wwwroot\\crm\\themes\\Sugar5\\tpls\\header.tpl\" header.old.tpl",
            provider => powershell,
            require  => [
              Exec['Call runSilentInstall'],
            ],
          }

          # Copy header.tpl in C:\inetpub\wwwroot\crm\themes\Sugar5\tpls
          exec {'Copy new header.tpl':
            command  => "Copy-Item \"${cache_dir}\\inin-toolbar\\header.tpl\" \"C:\\inetpub\\wwwroot\\crm\\themes\\Sugar5\\tpls\"",
            provider => powershell,
            require  => [
              Vcsrepo["${cache_dir}/inin-toolbar"],
              Exec['Backup old header.tpl'],
            ],
          }

          # Copy CIC folder in C:\inetpub\wwwroot\crm\themes\Sugar5\tpls
          exec {'Copy CIC folder':
            command  => "Copy-Item \"${cache_dir}\\inin-toolbar\\cic\" \"C:\\inetpub\\wwwroot\\crm\" -Recurse",
            provider => powershell,
            require  => Exec['Copy new header.tpl'],
          }
        }
        none:
        {
          debug('ININ Toolbar will not be installed')
        }
        default:
        {
          fail("Unsupported inintoolbar \"${inintoolbar}\"")
        }
      }
    }
    default:
    {
      fail("Unsupported ensure \"${ensure}\"")
    }
  }
}