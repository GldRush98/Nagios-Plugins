<#
.SYNOPSIS 
  This is a Nagios Plugin designed to check the special Exchange OAuth certificate's expiration date. This certificate is special as even if you have a commercial certificate, and the special OAuth Cert expires, things will break.
.NOTES
  Author: Nick Overstreet <https://www.nickoverstreet.com/>
  To renew before expiration go to: ECP -> Servers -> Certificates and click on Renew for the "Microsoft Exchange Server Auth Certificate"
  To renew after expiration see: https://docs.microsoft.com/en-us/exchange/troubleshoot/administration/cannot-access-owa-or-ecp-if-oauth-expired
.EXAMPLE
  .\check_exchange_oauth.ps1
  The above will check the local Exchange server's OAuth certificat's expiration date. This is hard coded to a 30 and 7 threshold below in the $warn_days and $crit_days variables.
  NCPA example:
  -t '<token>' -P 5693 -M 'plugins/check_exchange_oauth.ps1'
  NOTE: You must run this in a 64-bit powershell since it is using the Exchange SnapIn! You must adjust your ncpa.cfg accordingly.
.LAST MODIFIED
  7-26-2021
#>

#You may change the warning/critical threshold days here:
$warn_days = 30
$crit_days = 7

#Add the Exchange PS extension. Note: Must be in a 64-bit PS shell!
try {
	Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction Stop
} Catch {
	Write-Host "UNKNOWN - Could not load Exchange SnapIn! (Not in a 64-bit shell?)"
	exit 3
}

#Get a list of all Exchange certificates, find the special Auth Cert, and get its expiration date
$count = 0
$expiration = "unest"
$cert_list = Get-ExchangeCertificate
ForEach ($certificate in $cert_list) {
	$name = $certificate | select -ExpandProperty Subject
	#This has always been the certificate's name on Exchange servers I have checked so this should be the name to always look for
	If ($name -eq "CN=Microsoft Exchange Server Auth Certificate") {
		$expiration = $certificate | select -ExpandProperty NotAfter
		$count++
	}
}

#Make sure we only have 1 Auth certificate. Otherwise it's not simple to determine which one is actually used, and there should always only be one any way
If ($count -gt 1) {
	Write-Host "UNKNOWN - There was more than 1 Auth Certificate found, please investigate and remove unused or expired certificates"
	exit 3
}
#Make sure our date is a valid format
If($expiration -is [DateTime]){
	#Value was a date, so everything seems to have worked
} else {
	Write-Host "UNKNOWN - Something went wrong pulling the expiration date and the returned value is not a valid date"
	Write-Host "Returned date: $expiration"
	exit 3
}

#Find the time span between now and expiration, do the comparisons and return the status
$message = "OK"
$exit_code = 0
$today = Get-Date
$timespan = New-TimeSpan -Start $today -End $expiration
$days = $timespan.Days

If ($days -lt $warn_days) {
	$message = "WARNING"
	$exit_code = 1
}
if ($days -lt $crit_days) {
	$message = "CRITICAL"
	$exit_code = 2
}

Write-Host "$message - OAuth Certificate valid until $expiration (expires in $days days) | days=$days;$warn_days;$crit_days"
exit $exit_code