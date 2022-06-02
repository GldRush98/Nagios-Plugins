<?php
//Description: Digest a list of CAPs (Common Alerting Protocol) and return status based on supplied state and county.
//The idea came from a python script that did the same thing, but the code hadn't been updated in over a decade and I got tired of putting in hacky work-arounds to keep it functioning.
//So here is a php version that is hopefully a lot simpler to understand and maintain going forward.
//By: Nick Overstreet
//Version: 1.0
//Last Modified: 5/25/2022

if(!isset($argv) || count($argv) != 3)
{
	echo "Missing or Wrong Paramater\n";
	echo "Usage: check_weather.php st county\n";
	echo "st is the 2 letter state abbreviation - il\n";
	echo "county is the full county name - sangamon\n";
	exit(3);
}else
{
	$state = strtolower($argv[1]);
	$county = $argv[2];
}

$cap_url = "https://alerts.weather.gov/cap/$state.php?x=0";

function curl_retrieve($url)
{
	if($url == ""){ return $url; }
	$retrycount=0;
	$ch = curl_init();
	$curlresult="";
	curl_setopt($ch, CURLOPT_URL,$url);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER,1);
	curl_setopt($ch, CURLOPT_TIMEOUT, 10);
	curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, FALSE); 
	curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, FALSE); 
	curl_setopt($ch, CURLOPT_USERAGENT, "check_weather/v1.0 (nagios monitoring)"); //Must set a useragent as the default automated agents are blocked
	while($curlresult=="" && $retrycount <= 2){
		$curlresult=curl_exec ($ch);
		$retrycount++;
	}
	curl_close ($ch);
	return $curlresult;
}

$special_alerts = 0; //Counts special alerts
$watch_alerts = 0;   //Counts watches
$warning_alerts = 0; //Counts warnings
$ignored_alerts = 0; //Counts ignored alerts (doesn't match county)
$total_alerts = 0;   //Counts the total number of alerts for the matched county
$alert_list = "";    //This is a list of the name of the alert, i.e. "Thunderstorm Watch"
$alert_details = ""; //This is a list of the alert details, i.e. "Thunderstorm Watch issued May 23 at 6:52PM CDT until May 23 at 10:00PM CDT by NWS"
$output = "Weather Unknown: Something went wrong."; //Default output state in case something weird happens
$exit_code = 3;      //Nagios Unknown return code

//Retrieve the xml data and convert NWS's special CAP event tags to something that won't break php's XML parser
$raw_data = curl_retrieve($cap_url);
$raw_data = str_replace("cap:", "cap_", $raw_data);

//If the retrieval looks like it has valid data, process it via the XML parser
//If we don't have proper data we are going to pretend it is okay because this service is NOTORIOUSLY unreliable during completely random times, and I don't want alerts for when their service isn't working right.
if(stripos($raw_data, "NWS CAP Server")!==false) //This string should always be in the valid data I believe
{
	$xml = new SimpleXMLElement($raw_data);
}else
{
	echo "Retrieval of CAP data was unsuccessful, unreliable service is unreliable.";
	exit(0);
}

#print_r($xml); //XML Output useful for debugging

//Loop through each alert in the CAP list
foreach($xml->entry as $alert)
{
	$this_event = $alert->cap_event; //The alert name, ie: Flood Warning
	$this_area = $alert->cap_areaDesc; //Counties under this alert, ie: Clay; Richland
		
	//Check if our county falls under this alert
	if(stripos($this_area, $county)!==false)
	{
		//Add the alert name and details to a list we'll output later
		$alert_list .= "$alert->cap_event, ";
		$alert_details .= "$alert->title\n";
		
		//Check for watch/warning/other. This is the "simplest" way of doing this IMO, because all of the CAP messages like status, severity, and certainty have very ambigous meanings and different combinations mean different things.
		if(stripos($this_event, "watch")!==false)
		{
			//This alert is a watch
			$watch_alerts++;
		}elseif(stripos($this_event, "warning")!==false)
		{
			//This alert is a warning
			$warning_alerts++;
		}else
		{
			//Something that isn't a watch or warning, but still an alert, probably a special statement or advisory of some type.
			$special_alerts++;
		}
		$total_alerts++;

	}else //County check
	{
		$ignored_alerts++;
	}

}//foreach alert loop
//trim alert list:
$alert_list = rtrim($alert_list, ", ");

//Going to treat specials as a warning level. A higher alert level (warning) will override the lower (watch/special) alert level
//Set the output messages and return codes accordingly
if($special_alerts > 0)
{
	$output = "Weather Warning (Special): $alert_list";
	$exit_code = 1;
}
if($watch_alerts > 0)
{
	$output = "Weather Warning: $alert_list";
	$exit_code = 1;
}
if($warning_alerts > 0)
{
	$output = "Weather Critical: $alert_list";
	$exit_code = 2;
}

//If no alerts were counted for us, set the OK message and return code
if($total_alerts == 0)
{
	$output = "Weather OK: No watches or warnings currently apply to $county county.";
	$exit_code = 0;
}

echo "$output | Special=$special_alerts, Watches=$watch_alerts, Warnings=$warning_alerts\n$alert_details";
exit($exit_code);
?>