<?php
//Description: Counts the number of files in a directory are within specified thresholds
//Usage: check_file_count.php "$directory" $warning $critical
//Example: check_file_count.php "c:\directory" 50 100
//Note: This was written for Windows but will also work on Linux! Written for PHP5.
//By: Nick Overstreet | http://nickoverstreet.com | me@nickoverstreet.com
//Version 1.0 | Last modified: 3/12/2018
//Windows nsc.ini example:
//[External Scripts]
//check_file_count=scripts\php.exe scripts\check_file_count.php "D:\Data" 50 100

//I know doing this may generate undefined offset errors, but you still get an error, so I'm fine with it
$dir = $argv[1];
$warn = $argv[2];
$crit = $argv[3];
$file_count=0;

//Do some sanity checks before getting on to the work:
if(!is_dir($dir))
{
	//echo $dir;
	if ($dir == "-h")
	{
		echo "Counts the number of files in a directory are within specified thresholds \n";
		echo "Usage: php $argv[0] \"[full path to directory]\" [warning] [critical] \n";
		echo "Example: php $argv[0] \"c:\\windows\\temp\" 100 200 \n";
	}else{
		echo "ERROR: Directory: $dir not found! \n";
	}
	exit(3);
}

//Need a trailing slash to be on the end, this should work for both Windows and Linux...
$dir .= "/";

if(!is_numeric($warn) || !is_numeric($crit))
{
	echo "ERROR: Both Warning and Critical values must be set and must be numbers! \n";
	exit(3);
}

if($warn > $crit)
{
	echo "ERROR: Warning value HIGHER than Critical value! \n";
	exit(3);
}

//Ok, sanity checks passed, count up the files in the directory
if($files=scandir($dir))
{
	//scandir returns an array of everything including directory, since we only want to count files, we do this
	foreach($files as $file)
	{
		if(!is_dir($dir . $file))
		{
			$file_count++;
		}
			
	}
}else{
	echo "ERROR: Couldn't parse directory contents! \n";
	exit(3);
}

//We have our file count, now compare to thresholds and return output, perfdata, and exit codes:
$output = "File count is $file_count |'file count'=$file_count;$warn;$crit \n";

if($file_count < $warn)
{
	echo "OK: $output";
	exit(0);
}elseif($file_count >= $warn && $file_count < $crit)
{
	echo "WARNING: $output";
	exit(1);
}elseif($file_count >= $crit)
{
	echo "CRITICAL: $output";
	exit(2);
}else{
	echo "ERROR: Something went terribly wrong! \n";
	exit(3);
}
?>
