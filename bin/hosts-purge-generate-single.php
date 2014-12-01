#!/usr/local/bin/php
<?php


// Get work directory
if ($argc != 2) {
    throw new Exception("Invalid number of arguments (1 required - dir to generate script for).");
}
$workDirectory = $argv[1];


// Configuration
if (!is_dir($workDirectory)) {
    throw new Exception("Work directory does not exist: $workDirectory");
}



// Get config file data
$configFile    = dirname(__FILE__) .'/../conf/hosts-purge.conf';
$configFileData = file_get_contents($configFile);



// Configure required options - FIXME



// Get config lines
$configLines = file($configFile, FILE_IGNORE_NEW_LINES);


// Initial parse
$configOpts  = array();
$configRules = array();
foreach($configLines as $configLineNumber => $configLine) {
    $configLine = preg_replace('/^\s*/', '', $configLine);
    $configLine = preg_replace('/#.*$/', '', $configLine);

    // Empty?
    if (preg_match('/^\s*$/', $configLine)) {
	continue;
    }

    // Rule?
    if (preg_match('/^rule\s/', $configLine)) {
	$configRules[$configLineNumber+1] = $configLine;
	continue;
    }

    // Option
    $configOpts[$configLineNumber+1] = $configLine;
}
//print_r($configRules);
//print_r($configOpts);



// Parse config options
$config_backupPeriod = false;
$config_consider     = false;
$config_dateFormat   = false;
foreach ($configOpts as $configOptLine => $configOpt) {
    if (!preg_match('/^([-_a-zA-Z0-9]+)\s+"([^"]+)"$/', $configOpt, $matches)) {
	throw new Exception("Invalid configuration line $configOptLine: $configOpt");
    }
    $configVar   = $matches[1];
    $configValue = $matches[2];

    switch ($configVar) {

	case 'backup_period':
	    $config_backupPeriod = _parsePeriod($configValue);
	    if ($config_backupPeriod === false) {
		throw new Exception("Invalid period statement in configuration file at line $configOptLine: $configValue");
	    }
	    break;

	case 'consider':
	    $config_consider = _parsePeriod($configValue);
	    if ($config_consider === false) {
		throw new Exception("Invalid consider statement in configuration file at line $configOptLine: $configValue");
	    }
	    break;

	case 'date_format':
	    $config_dateFormat = $configValue;
	    break;

	default:
	    throw new Exception("Unknown configuration variable at line $configOptLine: $configVar");
    }
}



// Create array of possible keeps
$possibleInstances = array();
$possibleInstancesCount = $config_consider / $config_backupPeriod;
$currentTime = time();
$currentInstance = date($config_dateFormat, $currentTime);
for ($i=0; $i<$possibleInstancesCount; $i++) {
    $instanceTime = $currentTime - ($i * $config_backupPeriod);
    $instanceTag  = date($config_dateFormat, $instanceTime);
    $possibleInstances[$instanceTag] = false;
}
//echo "pic=$possibleInstancesCount\n";
//print_r($possibleInstances);



// Parse rules
foreach ($configRules as $configRuleLine => $configRule) {
    if (!preg_match('/^rule\s+(older_than)\s+"([^"]+)"\s+(keep)\s+"([^"]+)"$/', $configRule, $matches)) {
	throw new Exception("Invalid configuration rule at line $configRuleLine: $configRule");
    }
    $ruleCond        = $matches[1];
    $ruleCondParam   = $matches[2];
    $ruleAction      = $matches[3];
    $ruleActionParam = $matches[4];
    //echo $configRule;
    //print_r($matches);

    if ($ruleCond != 'older_than') {
	throw new Exception("Invalid rule condition at line $configRuleLine: $ruleCond");
    }

    $ruleCondTime = _parsePeriod($ruleCondParam);
    if ($ruleCondTime === false) {
	throw new Exception("Invalid rule condition parameter at line $configRuleLine: $ruleCondParam");
    }

    if ($ruleAction != 'keep') {
	throw new Exception("Invalid rule action at line $configRuleLine: $ruleAction");
    }

    switch ($ruleActionParam) {

	// FIXME to loop through available instances
	case 'all':
	    $regardedInstancesCount = ($config_consider / $config_backupPeriod) - ($ruleCondTime / $config_backupPeriod);
	    //echo "ric=$regardedInstancesCount\n";
	    for ($i=0; $i<$regardedInstancesCount; $i++) {
	        $instanceTime = $currentTime - $ruleCondTime - ($i * $config_backupPeriod);
	        $instanceTag  = date($config_dateFormat, $instanceTime);
	        $possibleInstances[$instanceTag] = 'keep';
	    }
    	    
	    break;

	case 'none':
	    $regardedInstancesCount = ($config_consider / $config_backupPeriod) - ($ruleCondTime / $config_backupPeriod);
	    //echo "ric=$regardedInstancesCount\n";
	    for ($i=0; $i<$regardedInstancesCount; $i++) {
	        $instanceTime = $currentTime - $ruleCondTime - ($i * $config_backupPeriod);
	        $instanceTag  = date($config_dateFormat, $instanceTime);
	        $possibleInstances[$instanceTag] = 'delete';
	    }

	    break;

	default:
	    foreach ($possibleInstances as $instanceTag => $instanceValue) {
		if (preg_match("/^$ruleActionParam$/", $instanceTag)) {
	    	    $possibleInstances[$instanceTag] = 'keep';
		}
	    }
	    //throw new Exception("Invalid rule action parameter at line $configRuleLine: $ruleActionParam");
    }
}
ksort($possibleInstances);
//print_r($possibleInstances);


//foreach ($possibleInstances as $instanceTag => $instanceValue) {
//    if ($instanceValue === 'keep') echo "$instanceTag\n";
//}



// Read directory contents
if (!is_dir($workDirectory) !== false) {
    throw new Exception("ERROR: work directory is not a directory or does not exist: $workDirectory");
}

// Read directory contents
$dirHandle = opendir($workDirectory);
if ($dirHandle === false) {
    throw new Exception("ERROR: work directory can not be opened: $workDirectory");
}

/* This is the correct way to loop over the directory. */
$availableInstances = array();
$incompleteInstances = array();
$dateYesterday = date('Y-m-d', time() - 86400);
$dateToday     = date('Y-m-d');
$dateTomorrow  = date('Y-m-d', time() + 86400);

while (false !== ($file = readdir($dirHandle))) {
    if (($file == '.') || ($file == '..')) {
	continue;
    }

    // Skip yesterdays, todays and tomorrow's dirs
    if (preg_match("/^$dateYesterday/", $file) || preg_match("/^$dateToday/", $file) || preg_match("/^$dateTomorrow/", $file)) {
	continue;
    }

    $flagFile = "$workDirectory/$file/.complete";
    if (!file_exists($flagFile)) {
	$incompleteInstances[$file] = $file;
	//echo "WARNING: Ignoring because backup incomplete, flag file missing: $flagFile\n";
	continue;
    }
    $availableInstances[$file] = $file;
}
closedir($dirHandle);
ksort($availableInstances);
ksort($incompleteInstances);
$availableInstancesHash = array_values($availableInstances);
$availableInstancesRHash = array_flip($availableInstancesHash);
//print_r($availableInstances);
//print_r($availableInstancesHash);



// Which instances shall we keep and which shall be deleted
$instancesToKeep = array();
$instancesToDelete = array();
foreach ($possibleInstances as $instanceDate => $instanceAction) {
    if ($instanceAction == 'keep') {
	$instancesToKeep[$instanceDate] = $instanceDate;
    } elseif ($instanceAction == 'delete') {
	$instancesToDelete[$instanceDate] = $instanceDate;
    } else {
	throw new Exception("Invalid action: $instanceAction");
    }
}
$instancesToKeepHash = array_values($instancesToKeep);
$instancesToKeepRHash = array_flip($instancesToKeepHash);
//print_r($instancesToKeep);
//print_r($instancesToKeepHash);
//print_r($instancesToKeepRHash);




// Main loop which decides what to do
$instancesToKeepReal   = array();
$instancesToDeleteReal = array();
foreach ($instancesToKeepHash as $instanceIndex => $instanceDate) {
    $instanceIndex_next = $instanceIndex + 1;
    if (isset($instancesToKeepHash[$instanceIndex_next])) {
	$instanceDate_next = $instancesToKeepHash[$instanceIndex_next];
    } else {
	$instanceIndex_next = false;
	$instanceDate_next  = false;
    }

    // If it exists, schedule it for keeping
    if (isset($availableInstances[$instanceDate])) {
	$instancesToKeepReal[$instanceDate] = $instanceDate;
	continue;
    }

    // Otherwise try to find next instance, but it must not overlap with next instance
    //echo "Searching for next instance from $instanceDate...\n";
    foreach ($availableInstancesHash as $aiIndex => $aiDate) {
	//echo "  Checking $aiDate\n";
	//echo "    " . strcmp($aiDate, $instanceDate) . "\n";
	if (strcmp($aiDate, $instanceDate) > 0) {
	    //echo "    found\n";
	    break;
	}
    }
    if (strcmp($aiDate, $instanceDate_next) >= 0) {
	    //echo "    will be used for next instance ($instanceDate_next), skipping\n";
	    continue;
    }
    //echo "Using $aiDate instead of $instanceDate";
//    $instancesToKeepReal[$instanceDate] = $aiDate;
    $instancesToKeepReal[$aiDate] = $aiDate;
}
//print_r($instancesToKeepReal);



// Main loop which decides what to do
$instancesToDeleteReal = array();
foreach ($availableInstances as $instanceDate) {
    if (!isset($instancesToKeepReal[$instanceDate])) {
	$instancesToDeleteReal[$instanceDate] = $instanceDate;
    }
}
//print_r($instancesToDeleteReal);



// Output
echo "### Keep these instances\n";
foreach ($instancesToKeepReal as $instanceDate) {
    echo "# $instanceDate\n";
}
echo "\n";

echo "### Delete these instances\n";
foreach ($instancesToDeleteReal as $instanceDate) {
    echo "$instanceDate\n";
}
echo "\n";

echo "### Delete these instances (incomplete backups)\n";
foreach ($incompleteInstances as $instanceDate) {
    echo "$instanceDate\n";
}
echo "\n";






/*
 * Function to parse descriptive period into number of seconds
 */
function _parsePeriod ($strPeriod)
{
    if (!preg_match('/^([0-9]+)\s+(day|month|year)s?$/', $strPeriod, $matches)) {
	return false;
    }
    $number = $matches[1];
    $unit   = $matches[2];

    switch ($unit) {
	case 'day':
	    $multiplyBy = 86400;
	    break;
	case 'month':
	    $multiplyBy = 86400 * 30;
	    break;
	case 'year':
	    $multiplyBy = 86400 * 360;
	    break;
    }

    return $number * $multiplyBy;
}