# i-MSCP Postgrey plugin v1.2.0

Provides a greylisting implementation for Postfix using Postgrey policy server.

## Introduction

Posgtrey policy server, which implements greylisting, is a spam filtering
method that rejects email from external servers on the first try. Spammers
don't usually retry sending their messages, whereas legitimate mail servers do.

Homepage: http://postgrey.schweikert.ch/

## Requirements

- i-MSCP Serie ≥ 1.4.x

## Installation

1. Be sure that all requirements as stated in the requirements section are met
2. Upload the plugin through the plugin management interface
3. Edit the plugin configuration file according your needs
4. Activate the plugin through the plugin management interface

## Update

1. Be sure that all requirements as stated in the requirements section are met
2. Backup your plugin configuration file if needed
3. Upload the plugin through the plugin management interface

### Restore you plugin configuration file if needed

1. Restore your plugin configuration file (compare it with the new version first)
2. Update the plugin list through the plugin management interface

## Configuration

See [Configuration file](config.php)

When changing a configuration parameter in the plugin configuration file, don't
forget to trigger a plugin list update, else you're changes will not be token
into account.

## Troubleshooting

Postgrey policy server Ubuntu < 15.10 is broken. Daemon cannot be stopped. See:

- https://bugs.launchpad.net/ubuntu/+source/postgrey/+bug/981789
- https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=670681
- https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=630353

## License

    i-MSCP Postgrey plugin
    Copyright (C) 2015-2017 Laurent Declercq <l.declercq@nuxwin.com>
    
    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.
    
    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.
    
    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

See [LICENSE](LICENSE)
