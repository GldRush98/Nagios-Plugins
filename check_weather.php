<?php
//Description: Digest a list of CAPs (Common Alerting Protocol) and return status based on supplied state and county.
//The idea came from a python script that did the same thing, but the code hadn't been updated in over a decade and I got tired of putting in hacky work-arounds to keep it functioning.
//So here is a php version that is hopefully a lot simpler to understand and maintain going forward.
//By: Nick Overstreet
//Version: 1.1
//Last Modified: 7/26/2022

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

function striposarray($haystack, $needles, $offset = 0)
{
	foreach($needles as $needle)
	{
		if(stripos($haystack, $needle, $offset) !== false)
		{
			return true;
		}
	}
	return false;
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
$previous_state_file = sys_get_temp_dir() . DIRECTORY_SEPARATOR . "check_weather_state_" . substr(md5("$state$county"), 0, 8) . ".txt"; //A file name used to store the previous state if needed. A short hash is appended to make it unique to the state/county being checked
$rejected_alerts = array('child abduction'); //An array of phrases/words that will cause the alert to be completely ignored. Useful for things that aren't actual weather alerts such as domestic dispute alerts.

//Retrieve the xml data and convert NWS's special CAP event tags to something that won't break php's XML parser
$raw_data = curl_retrieve($cap_url);
$raw_data = str_replace("cap:", "cap_", $raw_data);

//If the retrieval looks like it has valid data, process it via the XML parser
if(stripos($raw_data, "NWS CAP Server")!==false) //This string should always be in the valid data I believe
{
	$xml = new SimpleXMLElement($raw_data);
}else
{
	//Check for a previous state file to return the previous state. If non exists, previous state is 0. This will prevent up/downs no matter what state it is in due to NWS's unreliable service.
	//i.e. if you have a heat/freeze advisory lasting several days and the NWS service goes down during that, we want to avoid up/down notifications caused by their service.
	if(file_exists($previous_state_file))
	{
		$previous_state = file_get_contents($previous_state_file);
		if(!is_numeric($previous_state))
		{
			//If for some reason it's not a number in our previous state file, go back to 0 and delete the file
			$previous_state = 0 ;
			unlink($previous_state_file);
		}
	}else
	{
		$previous_state = 0;
	}
	
	echo "Retrieval of CAP data was unsuccessful, assuming last known status code: $previous_state";
	exit(intval($previous_state));
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
		//Make sure this isn't an alert we should reject
		if(striposarray($alert->cap_event, $rejected_alerts)==false)
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
		}//Rejected alerts check
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

//Store previous state if necessary
if($exit_code == 0)
{
	//For a zero code we don't need a state file, so if one exists, delete it
	if(file_exists($previous_state_file))
	{
		unlink($previous_state_file);
	}
}else
{
	@file_put_contents($previous_state_file, $exit_code);
}

//Final output
echo "$output | Special=$special_alerts, Watches=$watch_alerts, Warnings=$warning_alerts\n$alert_details";
exit($exit_code);
?>
