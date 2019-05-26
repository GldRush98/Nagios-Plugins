<#
.SYNOPSIS 
  This is a Nagios Plugin designed to check for LDAP connectivity and optionally run a search query on the specified server

.NOTES
  Author: Nick Overstreet <https://www.nickoverstreet.com/>

.PARAMETER ADServer
  FQDN of an AD Server that the LDAP connection should be tested to

.PARAMETER ADPath
  Optionally, the group path to search for its existence on the specified LDAP server, wrap in quotes

.EXAMPLE
  .\check_ldap.ps1 contoso-dc1 'OU=Employees,DC=contoso,DC=com'
  The above will check that contoso-dc1 is reachable via LDAP, and that the Employees OU exists inside the contoso.com domain on it

.NSCLIENT CONFIGURATION
  [Wrapped Scripts]
  check_ldap=check_ldap.ps1 $ARG1$ '$ARG2$'

.LAST MODIFIED
  12-12-2018
#>

[CmdletBinding()]
param (
	[Parameter(Mandatory=$True)]
	[string]$ADServer,
	[string]$ADPath
)
$LDAP = "LDAP://" + $ADServer + ":389" #You can switch this port to 636 if you want to use LDAPS (secure) instead
try {
	$Connection = [ADSI]($LDAP)
	If ($Connection.Path) {
		#You can search for a person or a group, this uses standard ldap query syntax
		#https://social.technet.microsoft.com/wiki/contents/articles/5392.active-directory-ldap-syntax-filters.aspx#Filter_on_objectCategory_and_objectClass
		$Searcher = New-Object DirectoryServices.DirectorySearcher
		#$Searcher.Filter = '(&(objectCategory=person)(anr=jsmith))' #Search for a person
		#$Searcher.SearchRoot = 'LDAP://contoso-dc1/OU=Employees,DC=contoso,DC=com' #Example hardcoded query
		$Searcher.Filter = '(&(objectCategory=group))'
		$Searcher.SearchRoot = 'LDAP://' + $ADServer + '/' + $ADPath
		try {
			$Search_Output = $Searcher.FindAll()
			If ($?) {
				Write-Host "OK - LDAP Connection and AD Query Successful"
				#$Connection #If you want detail of the LDAP connection, uncomment this
				#$Searcher.FindAll() #If you want detail output of the query, uncomment this
				exit 0
			} else {
				Write-Host "UNKNOWN - Other Search Failure"
				exit 3
			}
		}
		Catch {
			If ($ADPath) {
				Write-Host "WARNING - LDAP Connection Successful, but AD Query Failed"
				exit 1
			} else {
				Write-Host "OK - LDAP Connection Successful"
				#echo $Connection #If you want detail of the LDAP connection, uncomment this
				exit 0
			}
		}

		Write-Host "UNKNOWN - Other LDAP Failure 2"
		exit 3
	} else {
		Write-Host "CRITICAL - LDAP Connection Failed"
		exit 2
	}
} 
Catch {
	Write-Host "UNKNOWN - Other LDAP Failure 1"
	exit 3
}