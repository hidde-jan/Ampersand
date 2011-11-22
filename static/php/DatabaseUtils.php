<?php
require __DIR__.'/../dbSettings.php';
// We need the __DIR__ because all require statements are relative to the path of the browser-requested php file.
// Otherwise, when DatabaseUtils is included by Interface.php, we would need 'dbSettings.php', but when included
// by php/Database.php, we would need '../dbSettings.php'.

  
$DB_errs = array();
    
function dbStartTransaction($dbName) {
  DB_doquer($dbName, 'START TRANSACTION');
}

function dbCommitTransaction($dbName) {
  DB_doquer($dbName, 'COMMIT');
}

function dbRollbackTransaction($dbName) {
  DB_doquer($dbName, 'ROLLBACK');
}
  
function DB_doquer($DbName, $quer)
{
  global $DB_link,$DB_errs;
  $DB_slct = mysql_select_db($DbName,$DB_link);
    
  $result=mysql_query($quer,$DB_link);
  if(!$result){
    error('Error '.($ernr=mysql_errno($DB_link)).' in query "'.$quer.'": '.mysql_error(),2);
    $DB_errs[]='Error '.($ernr=mysql_errno($DB_link)).' in query "'.$quer.'"';
    return false;
  }
  if($result===true) return true; // succes.. but no contents..
  $rows=Array();
  while (($row = @mysql_fetch_array($result))!==false) {
    $rows[]=$row;
    unset($row);
  }
  return $rows;
}

function getTopLevelInterfacesForConcept($concept) {
  global $allInterfaceObjects;
  $interfacesForConcept = array();
  foreach($allInterfaceObjects as $interface) {
    if ($interface['srcConcept']==$concept)
    $interfacesForConcept[] = $interface;
  }
  return $interfacesForConcept;
}


// Misc utils

function firstRow($rows) {
  return $rows[0];
}

function firstCol($rows) {
  foreach ($rows as $i=>&$v)
  $v=$v[0];
  return $rows;
}

function targetCol($rows) {
  foreach ($rows as $i=>&$v)
  $v=$v['tgt'];
  return $rows;
}

function getCoDomainAtoms($db, $atom, $selectRel) {
  return targetCol(DB_doquer($db, selectCoDomain($atom, $selectRel)));
}

function selectCoDomain($atom, $selectRel) {
  return 'SELECT DISTINCT `tgt` FROM ('.addSlashes($selectRel).') as results where src=\''.addSlashes($atom).'\'';
}


// Html generation utils

function printBinaryTable($table) {
  echo '<table>';
  foreach ($table as $row)
  echo '<tr><td>'.$row['src'].'</td><td>'.$row['tgt'].'</td></tr>';
  echo '</table>';
}

function echoLn($str) {
  echo $str.'<br/>';
}

function emit(&$lines,$line) {
  $lines.=$line."\n";
}

// for use in specifiying values for attributes to html elements (eg. <div attr=VALUE>)
// " -> &quot,  
function showHtmlAttrStr($str) {
  return '"'.escapeHtmlAttrStr($str).'"';
}

function escapeHtmlAttrStr($str) {
  return str_replace(array('"'), array('&quot;'), $str); // we do addSlashes and replace \" by &quot; and \' by '
}

function showJsStr($str) {
  return "'".escapeJsStr($str)."'";
}

function escapeJsStr($str) {
  return addSlashes($str);
}

function jsBool($b) {
	return $b ? 'true' : 'false';
}
// This is needed for non-javascript urls, where javascript would call encodeURIComponent
// We only handle the &, the browser takes care of the rest.
function escapeURI($str) {
    return str_replace(array('&'), array('%26'), $str); // replace & by %26
}
?>