# Nagios-Plugins
A plugin or two I've written or modified for use in Nagios

**check_bgp.sh**	- [*Linux*] Check the bgp peer values of the vyatta software router. Useful for monitoring peer connections and can indicate peering issues if the value is not what you expect.

**check_exchange_oauth.ps1** - [*Windows*] Checks the special Exchange OAuth certificate's expiration date. This certificate is a special internal certificate Exchange servers use for backend admin functions and mail flow. If this certificate unexpectedly expires, things will break.

**check_file_count.php** - [*Windows/Linux*] Counts the number of files in a directory to see if they are within specified thresholds. Written for Windows, but should run on Linux too.

**check_file_exists.sh** - [*Linux*] Checks if the specified file (or directory) exists on the system.

**check_kernel_version**	- [*Linux*] Checks if your RHEL/CentOS system is running the newest installed kernel. If a newer kernel is installed and not running, that likely indicates the system needs a reboot to use the new kernel.

**check_ldap.ps1**	- [*Windows*] Check for LDAP connectivity and optionally run a search query on the specified server.

**check_local_certs.sh** - [*Linux*] Loops through every LetsEncrypt fullchain.pem file in the letsencrypt directory and checks that they're currently valid.

**check_nic_speed.php** - [*Windows*] Checks your network card's link speed, to make sure it is connected at what it is supposed to (i.e. gigabit).

**check_ookla.sh**	- [*Linux*] Monitors your internet speed with Ookla's speedtest CLI program.

**check_pjsip_extensions** - [*Linux*]  Check the Asterisk output of pjsip show endpoints, verify the extensions, and report it to Nagios. Can alert on number of Avail extensions.

**check_pjsip_transports** - [*Linux*] Check the Asterisk output of pjsip show endpoints, verify the Transports (sip providers), and report it to Nagios. Can alert when transport number is not the expected count.

**check_ufw** - [*Linux*] Check the UFW (Ultimate FireWall) status. This checks several things regarding UFW's state, including active status, incoming policy, outgoing policy, logging, and rule count.

**check_weather.php** - [*N/A*] A plugin that runs locally on your Nagios machine and checks NWS's Weather Alert system for any active Watches or Warnings in your county. It may be useful to know if a weather event could be impacting your particular location. Should work for any State/Territory and County covered by the NWS.

**check_yum.sh** - [*Linux*] A quick and simple script to check for updates via yum on Redhat/CentOS systems, with some perfdata.

**ping_remote.bat** - [*Windows*] Allow Windows to ping hosts and return the results via your Nagios agent.
