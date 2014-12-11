=head1 NAME

 Plugin::PhpSwitcher

=cut

# i-MSCP PhpSwitcher plugin
# Copyright (C) 2014 Laurent Declercq <l.declercq@nuxwin.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#

# TODO PHP5-FPM support

package Plugin::PhpSwitcher;

use strict;
use warnings;

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use iMSCP::Debug;
use iMSCP::Database;
use Servers::httpd;
use iMSCP::Dir;
use JSON;
use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 This package implements the backend for the PhpSwitcher plugin.

=head1 PUBLIC METHODS

=over 4

=item run()

 Register event listeners

 Return int 0 on success, other on failure

=cut

sub run
{
	my $self = $_[0];

	if($self->{'server_implementation'} ~~ ['apache_fcgid']) {
		$self->{'eventManager'}->register('beforeHttpdAddDmn', \&setPhpData);
		$self->{'eventManager'}->register('beforeHttpdRestoreDmn', \&setPhpData);
		$self->{'eventManager'}->register('beforeHttpdAddSub', \&setPhpData);
		$self->{'eventManager'}->register('beforeHttpdRestoreSub', \&setPhpData);

		$self->{'eventManager'}->register('beforeHttpdDisableDmn', \&removePhpConfDir);
		$self->{'eventManager'}->register('beforeHttpdDelDmn', \&removePhpConfDir);
		$self->{'eventManager'}->register('beforeHttpdDisableSub', \&removePhpConfDir);
		$self->{'eventManager'}->register('beforeHttpdDelSub', \&removePhpConfDir);

		$self->{'eventManager'}->register('afterDispatchRequest', sub {
			my $rs = $_[0];

			unless($rs) {
				my $ret = $self->{'db'}->doQuery(
					'dummy',
					"
						UPDATE
							php_switcher_version
						SET
							version_confdir_path_prev = NULL, version_status = 'ok'
						WHERE
							version_status = 'tochange'
					"
				);
				unless(ref $ret eq 'HASH') {
					error($ret);
					return 1;
				}

				$ret = $self->{'db'}->doQuery(
					'dummy', "DELETE FROM php_switcher_version WHERE version_status = 'todelete'"
				);
				unless(ref $ret eq 'HASH') {
					error($ret);
					return 1;
				}

				0;
			} else {
				my $ret = $self->{'db'}->doQuery(
					'dummy',
					(
						"UPDATE plugin SET plugin_error = ? WHERE plugin_name = ?",
						(scalar getMessageByType('error') || 'unknown error'),
						'PhpSwitcher'
					)
				);
				error($ret) unless ref $ret eq 'HASH';
			}

			$rs;
		});
	}

	0;
}

=item enable()

 Process enable tasks

 Return int 0 on success, other on failure

=cut

sub enable
{
	$_[0]->run();
}

=item disable()

 Process disable tasks

 Return int 0 on success, other on failure

=cut

sub disable
{
	my $self = $_[0];

	$self->{'eventManager'}->register('beforeHttpdAddDmn', \&removePhpConfDir);
	$self->{'eventManager'}->register('beforeHttpdAddSub', \&removePhpConfDir);
}

=item change()

 Process change tasks

 Return int 0 on success, other on failure

=cut

sub change
{
	my $self = $_[0];

	if($self->{'server_implementation'} eq 'apache_fcgid') {
		# On change we simply run normal workflow to setup per customer PHP version
		$self->run();
	} else {
		# In case the admin switched to an unsupported HTTPD server implementation, we must disable the plugin
		$self->{'eventManager'}->register('beforeHttpdAddDmn', \&removePhpConfDir);
		$self->{'eventManager'}->register('beforeHttpdAddSub', \&removePhpConfDir);

		$self->{'eventManager'}->register('afterDispatchRequest', sub {
			my $rs = $self->{'db'}->doQuery(
				'dummy', "UPDATE plugin SET plugin_status = 'disabled' WHERE plugin_name = 'PhpSwitcher'"
			);
			unless(ref $rs eq 'HASH') {
				error($rs);
				return 1;
			}

			0;
		});

		0;
	}
}

=back

=head1 EVENT LISTENERS

=over 4

=item setPhpData(\%data)

 Listener responsible to set PHP data ( confdir and binary path ) for the given domain/subdomain

 Param hash \%data Data as provided by the Alias|Domain|SubAlias|Subdomain modules
 Return int 0 on success, other on failure

=cut

sub setPhpData
{
	my ($self, $data) = (__PACKAGE__->getInstance(), $_[0]);

	my $phpVersionAdmin = (defined $self->{'memcached'}) ? $self->{'memcached'}->get('php_version_admin') : undef;

	# Get data from database only if they are not cached yet
	unless(defined $phpVersionAdmin) {
		$phpVersionAdmin = $self->{'db'}->doQuery(
			'admin_id',
			"
				SELECT
					admin_id, version_binary_path, version_confdir_path_prev, version_confdir_path, version_status
				FROM
					php_switcher_version
				INNER JOIN
					php_switcher_version_admin USING (version_id)
				WHERE
					version_status IN('ok', 'tochange', 'todelete')
			"
		);
		unless(ref $phpVersionAdmin eq 'HASH') {
			error($phpVersionAdmin);
			return 1;
		}

		# Cache data if memcached support is enabled
		$self->{'memcached'}->set('php_version_admin', $phpVersionAdmin) if $self->{'memcached'};
	}

	my $adminId = $data->{'DOMAIN_ADMIN_ID'};

	if($phpVersionAdmin->{$adminId}) {
		if($phpVersionAdmin->{$adminId}->{'version_status'} eq 'todelete') { # Customer PHP version will be deleted
			# Remove Customer's PHP configuration directory
			my $rs = iMSCP::Dir->new(
				'dirname' => "$phpVersionAdmin->{$adminId}->{'version_confdir_path'}/$data->{'DOMAIN_NAME'}"
			)->remove();
			return $rs if $rs;

			# Remove customer's PHP version data from cache
			if($self->{'memcached'}) {
				delete $phpVersionAdmin->{$adminId};
				$self->{'memcached'}->set('php_version_admin', $phpVersionAdmin);
			}

			# Reset back Customer's PHP version
			$self->{'httpd'}->{'config'}->{'PHP_CGI_BIN'} = $self->{'default_binary_path'};
			$self->{'httpd'}->{'config'}->{'PHP_STARTER_DIR'} = $self->{'default_confdir_path'};
		} elsif($phpVersionAdmin->{$adminId}->{'version_status'} eq 'tochange') { # Customer's PHP version is updated
#			# Remove Customer's previous PHP configuration directory
#			my $prevConfDir = $phpVersionAdmin->{$adminId}->{'version_confdir_path_prev'};
#
#			if($prevConfDir) {
#				my $rs = iMSCP::Dir->new('dirname' => "$prevConfDir/$data->{'DOMAIN_NAME'}")->remove();
#				return $rs if $rs;
#
#				# Update cache
#				if($self->{'memcached'}) {
#					delete $phpVersionAdmin->{$adminId}->{'version_confdir_path_prev'};
#					$self->{'memcached'}->set('php_version_admin', $phpVersionAdmin);
#				}
#			}

			# Set customer PHP paths according its PHP version
			$self->{'httpd'}->{'config'}->{'PHP_CGI_BIN'} = $phpVersionAdmin->{$adminId}->{'version_binary_path'};
			$self->{'httpd'}->{'config'}->{'PHP_STARTER_DIR'} = $phpVersionAdmin->{$adminId}->{'version_confdir_path'};
		} else {
			# Set customer PHP paths according its PHP version
			$self->{'httpd'}->{'config'}->{'PHP_CGI_BIN'} = $phpVersionAdmin->{$adminId}->{'version_binary_path'};
			$self->{'httpd'}->{'config'}->{'PHP_STARTER_DIR'} = $phpVersionAdmin->{$adminId}->{'version_confdir_path'};
		}
	} else {
		# Set customer PHP paths to default PHP version
		$self->{'httpd'}->{'config'}->{'PHP_CGI_BIN'} = $self->{'default_binary_path'};
		$self->{'httpd'}->{'config'}->{'PHP_STARTER_DIR'} = $self->{'default_confdir_path'};
	}

	Plugin::PhpSwitcher::removePhpConfDir($data);
}

=item removePhpConfDir(\%data)

 Listener responsible to delete PHP configuration directory for the given domain/subdomain

 Param hash \%data Data as provided by the Alias|Domain|SubAlias|Subdomain modules
 Return int 0 on success, other on failure

=cut

sub removePhpConfDir
{
	my ($self, $data) = (__PACKAGE__->getInstance(), $_[0]);

	my $phpConfDirs = ($self->{'memcached'}) ? $self->{'memcached'}->get('php_confdirs') : undef;

	unless(defined $phpConfDirs) {
		$phpConfDirs = $self->{'db'}->doQuery(
			'version_confdir_path',
			'SELECT version_confdir_path FROM php_switcher_version GROUP BY version_confdir_path'
		);
		unless(ref $phpConfDirs eq 'HASH') {
			error($phpConfDirs);
			return 1;
		}

		$phpConfDirs->{$self->{'default_confdir_path'}} = {
			'version_confdir_path' => $self->{'default_confdir_path'}
		};

		$self->{'memcached'}->set('php_confdirs', $phpConfDirs) if $self->{'memcached'};
	}

	if(%{$phpConfDirs}) {
		for my $phpConfDir(keys %{$phpConfDirs}) {
			my $rs = iMSCP::Dir->new('dirname' => "$phpConfDir/$data->{'DOMAIN_NAME'}")->remove();
			return $rs if $rs;
		}
	}

	0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init()

 Initialize plugin instance

 Return Plugin::PhpSwitcher

=cut

sub _init
{
	my $self = $_[0];

	$self->{'server_implementation'} = $main::imscpConfig{'HTTPD_SERVER'};
	$self->{'db'} = iMSCP::Database->factory();

	if($self->{'server_implementation'} ~~ ['apache_fcgid']) {
		my $pluginConfig = $self->{'db'}->doQuery(
			'plugin_name', 'SELECT plugin_name, plugin_config FROM plugin WHERE plugin_name = ?', 'PhpSwitcher'
		);
		unless(ref $pluginConfig eq 'HASH') {
			fatal($pluginConfig);
		} else {
			$self->{'config'} = decode_json($pluginConfig->{'PhpSwitcher'}->{'plugin_config'});
		}

		$self->{'httpd'} = Servers::httpd->factory();

		$self->{'default_binary_path'} = $self->{'httpd'}->{'config'}->{'PHP_CGI_BIN'};
		$self->{'default_confdir_path'} = $self->{'httpd'}->{'config'}->{'PHP_STARTER_DIR'};

		# Small-haking to avoid too many IO operations. This also avoid conffile overriding on failure
		my %config = %{$self->{'httpd'}->{'config'}};
		untie %{$self->{'httpd'}->{'config'}};
		%{$self->{'httpd'}->{'config'}} = %config;

		$self->{'memcached'} = $self->_getMemcached();
	}

	$self;
}

=item _getMemcached()

 Get memcached instance

 Return Cache::Memcached::Fast or undef in case memcached server is not enabled or not available

=cut

sub _getMemcached
{
	my $self = $_[0];

	my $memcached;

	if($self->{'config'}->{'memcached'}->{'enabled'}) {
		if(eval 'require Cache::Memcached::Fast') {
			require Digest::SHA;
			Digest::SHA->import('sha1_hex');

			$memcached = new Cache::Memcached::Fast({
				servers => ["$self->{'config'}->{'memcached'}->{'hostname'}:$self->{'config'}->{'memcached'}->{'port'}"],
				namespace => substr(sha1_hex('PhpSwitcher'), 0 , 8) . '_', # Hashed manually (expected)
				connect_timeout => 0.5,
				io_timeout => 0.5,
				close_on_error => 1,
				compress_threshold => 100_000,
				compress_ratio => 0.9,
				compress_methods => [ \&IO::Compress::Gzip::gzip, \&IO::Uncompress::Gunzip::gunzip ],
				max_failures => 3,
				failure_timeout => 2,
				ketama_points => 150,
				nowait => 1,
				serialize_methods => [ \&Storable::freeze, \&Storable::thaw ],
				utf8 => 1
			});
		}
	}

	$memcached;
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
