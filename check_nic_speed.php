<?php
/*
A php script to determine the nic speed in Windows. Yes, php, I know and I'm sorry, but it was the easiest way for me to manipulate the data and not have to rely on powershell
Written by: Nick Overstreet <https://www.nickoverstreet.com/>
Last Modified: 3/16/2021

Append a php handler to the end of your ncpa.cfg file:
.php = php $plugin_name $plugin_args
Make sure that php is a environmental variable on your system, otherwise specify its full path

If using NSclient++, nsclient.ini example:
[/settings/external scripts/wrapped scripts]
check_nic_speed = check_nic_speed.php Intel(R)_82579LM_Gigabit_Network_Connection 1000

[/settings/external scripts/wrappings]
; PHP script - Command line used for wrapped php scripts
php = php scripts\\%SCRIPT% %ARGS%
*/
$found = false;
$return = 3;
$nicspeed = array();
$output_cli = `wmic NIC where NetEnabled=true get Name, Speed`;
$output = explode("\n", $output_cli);
if (count($output) < 4)
{
	echo "UNKNOWN: No NICs found from wmic command!\n";
	echo "CLI Output: $output_cli\n";
	exit(3);
}

$header = array_shift($output); //Remove header (save it for calculating line length)
array_pop($output); //Remove blank line
array_pop($output); //Remove blank line

$str_locate = strpos($header, "Speed");
foreach ($output as $line)
{
	//Create an array of nic-speed pairs
	//Note: these substr cutoffs are automatically calculated based on the location of the word Speed in the header.
	//If Windows changes this output at some point, this may need to be adjusted tweaked (find by running the wmic command and counting the characters, including spaces):
	$nic_push = str_replace(" ", "_", trim(substr($line,0,$str_locate))); //Replace spaces in NIC name with underscores so we can pass the nic name as one single arg
	$speed_push = trim(substr($line,$str_locate,11))/1000000;
	array_push($nicspeed, array($nic_push, $speed_push));
}
#print_r($nicspeed); //Debug
#print_r($argv); //Debug

if (count($argv) != 3 || !is_numeric($argv[2]))
{
	echo "Usage: php $argv[0] <NIC_Name> <Speed>\n";
	echo "Available NICs and their current Speed:\n";
	foreach ($nicspeed as $thisnic){ echo " $thisnic[0] ($thisnic[1] Mbps) \n"; }
	echo "Speed is specified in Mbps (Typical values = 10, 100, 1000)\n";
	echo "example: php $argv[0] " . $nicspeed[0][0] . " " . $nicspeed[0][1] . "\n"; 
	exit(3);
}

$expected_nic = $argv[1];
$expected_speed = $argv[2];

foreach ($nicspeed as $thisnic)
{
	$nic = $thisnic[0];
	$speed = $thisnic[1];
	if ($nic == $expected_nic)
	{
		$found = true;
		if ($speed == $expected_speed)
		{
			echo "OK: $nic link at $speed Mbps|NIC_Speed=" . $speed . "Mbps;";
			$return = 0;
		}else{
			echo "WARNING: $nic link at $speed Mbps, expected to be at $expected_speed Mbps|NIC_Speed=" . $speed . "Mbps;";
			$return = 1;
		}
	}//Not the nic we're looking for
}
if (!$found)
{
	echo "CRITICAL: NIC $expected_nic not found!\n";
	echo "Available NICs and their current Speed:\n";
	foreach ($nicspeed as $thisnic){ echo " $thisnic[0] ($thisnic[1] Mbps) \n"; }
	$return = 2;
}

exit($return);
?>