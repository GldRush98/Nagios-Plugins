# Nagios-Plugins
A plugin or two I've written or modified for use in Nagios

**check_bgp.sh**	- [*Linux*] Check the bgp peer values of the vyatta software router. Useful for monitoring peer connections and can indicate peering issues if the value is not what you expect.

**check_exchange_oauth.ps1** - [*Windows*] Checks the special Exchange OAuth certificate's expiration date. This certificate is a special internal certificate Exchange servers use for backend admin functions and mail flow. If this certificate unexpectedly expires, things will break.

**check_file_count.php** - [*Windows/Linux*] Counts the number of files in a directory to see if they are within specified thresholds. Written for Windows, but should run on Linux too.

**check_kernel_version**	- [*Linux*] Checks if your RHEL/CentOS system is running the newest installed kernel. If a newer kernel is installed and not running, that likely indicates the system needs a reboot to use the new kernel.

**check_ldap.ps1**	- [*Windows*] Check for LDAP connectivity and optionally run a search query on the specified server.

**check_nic_speed.php** = [*Windows*] Checks your network card's link speed, to make sure it is connected at what it is supposed to (i.e. gigabit).

**check_ookla.sh**	- [*Linux*] Monitors your internets speed with Ookla's speedtest CLI program.

**check_yum.sh** - [*Linux*] A quick and simple script to check for updates via yum on Redhat/CentOS systems, with some perfdata.

**ping_remote.bat** - [*Windows*] Allow Windows to ping hosts and return the results via your Nagios agent.
