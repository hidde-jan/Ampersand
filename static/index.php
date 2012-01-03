<?php
error_reporting(E_ALL^E_NOTICE); 
ini_set("display_errors", 1);

require "Generics.php"; 
// defines $dbName, $isDev, $relationTableInfo, $allInterfaceObjects, $allRulesSql, $invariantRuleNames, and $allRoles

require "php/DatabaseUtils.php";
require "php/Database.php";
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Strict//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>

<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="no-cache">
<meta http-equiv="Expires" content="-1">
<meta http-equiv="cache-Control" content="no-cache"> 
 
<link href="css/Ampersand.css" rel="stylesheet" type="text/css"/>
<link href="css/Custom.css" rel="stylesheet" type="text/css"/>

<link href="css/smoothness/jquery-ui-1.8.16.custom.css" rel="stylesheet" type="text/css"/>
<script src="js/jquery-1.6.2.min.js"></script>
<script src="js/jquery-ui-1.8.16.custom.min.js"></script>

<script src="js/Ampersand.js"></script>
<script type="text/javascript">

function init() {
  initialize();
}

<?php echo generateInterfaceMap(); ?>

</script>
</head>
<body onload="init()">
<div id="Header"><div id="Logo"></div><div id="Decoration"></div></div>

<?php
$roleNr = isset($_REQUEST['role']) ? $_REQUEST['role'] : -1; // role=-1 (or not specified) means no role is selected
$roleName = $roleNr>=0 ? $allRoles[$roleNr]['name'] : '';

echo '<div id="TopLevelInterfaces">';
echo '<div class="MenuBar">';
//echo '<ul>';

// TODO: until there is more time to design a nice user interface, we put the role selector as a list item in the top-level interfaces list

echo '<div class="MenuItem" id="LinkToMain"><a href="index.php'.($roleNr>=0? '?role='.$roleNr : '').'"><span class=TextContent>Main</span></a></div>';
echo topLevelInterfaceLinks();

echo '<select id=RoleSelector onchange="changeRole()">';
echo '<option value="-1"'.($roleNr==-1 ? ' selected=yes' : '').'>Algemeen</option>'; // selected if role==0 or role is not specified
for ($i=0; $i<count($allRoles); $i++) {
  $roleNm = $allRoles[$i]['name'];
  echo '<option value="'.$i.'"'.($roleNr==$i ? ' selected=yes' : '').'>'.$roleNm.'</option>';
}
echo '</select>'; // the select is in front of the rest, so it floats to the right before the reset item does.

if ($isDev) { // with --dev on, we show the reset-database link in the menu bar
  echo '<div class="MenuItem" id="MenuBarReset"><a href="Installer.php"><span class=TextContent>Reset</span></a></div>';
}

echo '</div>'; // .MenuBar
echo '</div>'; // #TopLevelInterfaces

if (!isset($_REQUEST['interface']) || !isset($_REQUEST['atom'])) {
  echo '<ul id="Maintenance">';
  echo '<li id="Reset"><a href="Installer.php"><span class=TextContent>Reset database</span></a></li>';
  echo '</ul>';
  
  echo '<h3 id="CreateHeader"><span class=TextContent>Create</span></h3>';
  echo newAtomLinks();
  echo '<form><h3 id="CreateGotoHeader"><span class=TextContent>Create or go to identifier </span><input id="inputID" type="text" onkeyup="showID(this.value)" size="20" /></form></h3>';
  echo newAtomLinksById();

  // Add dummy AmpersandRoot with just the refresh interval and timestamp to auto update signals.
  // This will be obsolete once these and other properties are in a separate div. 
  echo "<div id=AmpersandRoot refresh=$autoRefreshInterval timestamp=\"".getTimestamp()."\"/>"; 
  
  echo '<div id=SignalAndPhpLogs>';
  genSignalLogWindow($roleNr, $roleName);
  echo '</div>';
} else {
    
  $interface=$_REQUEST['interface'];
  $atom = $_REQUEST['atom'];
  $concept = $allInterfaceObjects[$interface]['srcConcept'];
  
  $isNew = $concept!='ONE' && !isAtomInConcept($atom,$concept);
  // If the atom is not in the concept, this means that a new atom was be created (and $atom is a time-based unique name).
  // We cannot use a url-encoded command for Create new, since such a url causes problems in the browser history. (pressing back 
  // could cause the creation of another atom) With the current method, going back or refreshing the url simply shows the new atom.
  // TODO: Once navigation is not done with urls anymore, we can employ a more elegant solution here.
  //
  // We add the atom to its concept in a temporary transaction, so we can generate the interface in the normal way (by querying
  // the database). When the interface is done, the transaction is rolled back. On save, the atom is added to the concept table
  // again.
  // TODO: with multiple users, this mechanism may lead to non-unique new atom names, until we enocode a session number
  //       in the unique atom name. But since the atom names are based on microseconds, the chances of a problem are pretty slim.
  if ($isNew) {
    DB_doquer($dbName, 'START TRANSACTION');
    addAtomToConcept($atom, $concept);
  }

echo '<div id=AmpersandRoot interface='.showHtmlAttrStr($interface).' atom='.showHtmlAttrStr($atom).
       ' concept='.showHtmlAttrStr($allInterfaceObjects[$interface]['srcConcept']).
       ' editing='.($isNew?'true':'false').' isNew='.($isNew?'true':'false').
       " refresh=$autoRefreshInterval dev=".($isDev?'true':'false').
       ' timestamp="'.getTimestamp().'">';

  echo '<div class=LogWindow id=EditLog minimized=false><div class=MinMaxButton></div><div class=Title>Edit commands</div></div>';
  echo '<div class=LogWindow id=ErrorLog minimized=false><div class=MinMaxButton></div><div class=Title>Errors</div></div>';
  
  echo '<div id=SignalAndPhpLogs>';
  echo '<div class=LogWindow id=PhpLog minimized=false><div class=MinMaxButton></div><div class=Title>Php log </div></div>';
  genSignalLogWindow($roleNr, $roleName);
  echo '</div>';
  
  echo '<button class="Button EditButton" onclick="startEditing()">Edit</button>';
  echo '<button class="Button SaveButton" onclick="commitEditing()">Save</button>';
  echo '<button class="Button CancelButton" onclick="cancelEditing()">Cancel</button>';

  // we need an extra ScrollPane div because the log windows need to be outside scroll area but inside ampersand root
  // (since their css depends on the 'editing' attribute)
  echo '<div id=ScrollPane>';
  echo generateAtomInterfaces($dbName, $allInterfaceObjects[$interface], $atom, true); 
  echo '</div>';
  
  echo '</div>';
  echo '<div id=Rollback></div>'; // needs to be outside AmpersandRoot, so it's easy to address all interface elements not in the Rollback
  
  if ($isNew) {
    DB_doquer($dbName, 'ROLLBACK');
  }
} ?>
</body>
</html>

<?php 

function topLevelInterfaceLinks() {
  global $allInterfaceObjects;
  global $roleNr;
  
  foreach($allInterfaceObjects as $interface) {
    if ($interface['srcConcept']=='ONE') // the interface attribute is there so we can style specific menu items with css
      echo '<div class="MenuItem" interface="'.escapeHtmlAttrStr(escapeURI($interface['name']))
          .'"><a href="index.php?interface='.escapeHtmlAttrStr(escapeURI($interface['name'])).'&atom=1'.($roleNr>=0? '&role='.$roleNr : '')
          .'"><span class=TextContent>'.htmlSpecialChars($interface['name']).'</span></a></div>';
  }
}

function newAtomLinks() {
  global $allInterfaceObjects;
  global $roleNr;
  
  echo '<ul id=CreateList>';
  foreach($allInterfaceObjects as $interface) {
    if ($interface['srcConcept']!='ONE') {
      $interfaceStr = escapeHtmlAttrStr(escapeURI($interface['name']));
      $conceptStr = escapeHtmlAttrStr(escapeURI($interface['srcConcept']));
      echo "\n<li interface='$interfaceStr'><a href=\"javascript:navigateToNew('$interfaceStr','$conceptStr')\">"
           .'<span class=TextContent>Create new '.htmlSpecialChars($interface['srcConcept'])
           .' ('.htmlSpecialChars($interface['name']).')</spin></a></li>';
    }
  }
  echo '</ul>';
}
function newAtomLinksById() {
  global $allInterfaceObjects;
  global $roleNr;
  
  echo '<ul id=CreateList>';
  foreach($allInterfaceObjects as $interface) {
    if ($interface['srcConcept']!='ONE') {
      $interfaceStr = escapeHtmlAttrStr(escapeURI($interface['name']));
      $conceptStr = escapeHtmlAttrStr(escapeURI($interface['srcConcept']));
      echo "\n<li interface='$interfaceStr'><a name=\"gotoID\" href=\"javascript:navigateToIdentifier('$interfaceStr')\">"
           .'<span class=TextContent>Create new or go to '.htmlSpecialChars($interface['srcConcept'])
           .' <a class=TextContent name="txtID"/></span> </a></li>';
    }
  }
  echo '</ul>';
}

function generateInterfaceMap() {
  global $allInterfaceObjects;
  
  echo 'function getInterfacesMap() {';
  echo '  var interfacesMap = new Array();';
  foreach($allInterfaceObjects as $interface) {
    echo '  mapInsert(interfacesMap, '.showHtmlAttrStr($interface['srcConcept']).', '.showHtmlAttrStr($interface['name']).');';
  }
  echo '  return interfacesMap;';
  echo '}';
}

function generateInterface($db, $interface, $srcAtom) {
/*
 *  <Interface label='interface label'>
 *   <Label>interface label</Label>
 *   <AtomList concept=.. [relation=..  relationIsFlipped=..]>
 *     ..
 *     for each $tgtAtom in codomain of relation of $interface
 *     <AtomRow rowType=Normal>         <DeleteStub/> <AtomListElt> generateAtomInterfaces($interface, $tgtAtom) </AtomListElt> </AtomRow>
 *     ..
 *     
 *     <AtomRow rowType=NewAtomTemplate> <DeleteStub/> <AtomListElt> generateAtomInterfaces($interface, null) </AtomListElt>     </AtomRow>
 *     
 *     <AtomRow rowType=InsertAtomStub> <DeleteStub/> <InsertStub>Insert new .. </InsertStub>                                  </AtomRow>
 *   </AtomList>
 * </Interface> 
 */
  
  $html = "";
  emit($html, '<div class=Interface label='.showHtmlAttrStr($interface['name']).'>');
  emit($html, "<div class=Label>".htmlSpecialChars($interface['name']).'</div>');
  
  if ($srcAtom == null)
    $codomainAtoms = array (); // in case the table would contain (null, some atom)  
  else
    $codomainAtoms = array_filter(getCoDomainAtoms($db, $srcAtom, $interface['expressionSQL'])); // filter, in case table contains ($srcAtom, null)

  if (count($codomainAtoms)==0 && $interface['min']=='One') 
    $codomainAtoms[] = ""; // if there should be at least one field, we add an empty field.
  
  $codomainAtoms[] = null; // the null is presented as a NewAtomTemplate (which is cloned when inserting a new atom)
  
  $nrOfAtoms = count($codomainAtoms)-1; // disregard the null for the NewAtomTemplate
  
  $relationAttrs = $interface['relation']=='' ? '' : ' relation='.showHtmlAttrStr($interface['relation']).' relationIsFlipped='.showHtmlAttrStr(jsBool($interface['relationIsFlipped']))
                                                    .' min='.showHtmlAttrStr($interface['min']).' max='.showHtmlAttrStr($interface['max'])
                                                    .' nrOfAtoms='.showHtmlAttrStr($nrOfAtoms); // 
  emit($html, '<div class="AtomList" concept='.showHtmlAttrStr($interface['tgtConcept']).$relationAttrs.'>');
  
  foreach($codomainAtoms as $i => $tgtAtom) { // null is the NewAtomTemplate
    emit($html, '<div class=AtomRow rowType='.($tgtAtom===null ?'NewAtomTemplate': 'Normal').'><div class=DeleteStub>&nbsp;</div>'.
                  '<div class=AtomListElt>');
    emit($html, generateAtomInterfaces($db, $interface, $tgtAtom));
    emit($html,'</div></div>');  
  }
  
  emit($html, '<div class=AtomRow rowType=InsertAtomRow><div class=DeleteStub>&nbsp;</div>'.
                '<div class=InsertStub>Insert new '.htmlSpecialChars($interface['tgtConcept']).'</div></div>');
  
  emit($html, '</div></div>'); // close .AtomList and .Interface
  return $html;
}

function generateAtomInterfaces($db, $interface, $atom, $isTopLevelInterface=false) {
/* if $interface is a top-level interface, we only generate for $interface itself
 * otherwise, we generate for its subinterfaces 
 * 
 *  <Atom atom='atom name'>
 *   <AtomName>atom name</AtomName>
 *   <InterfaceList>
 *     ..
 *     for each subInterface in $interface: generateInterface($interface, $atom)        (or $interface, if $isTopLevelInterface)
 *     ..
 *   </InterfaceList>
 * </Atom>
 * 
 * if $atom is null, we are presenting a template. Because ""==null and "" denotes an empty atom, we check with === (since "" !== null)
 */
  $html = "";
  $interfaces = $isTopLevelInterface ? array ($interface) : $interface['subInterfaces'];


  $nrOfInterfaces = count(getTopLevelInterfacesForConcept($interface['tgtConcept']));
  $hasInterfaces = $nrOfInterfaces == 0 ? '' : ' hasInterface=' . ($nrOfInterfaces == 1 ? 'single' : 'multiple');
  
  emit($html, '<div class=Atom atom='.showHtmlAttrStr($atom).$hasInterfaces.' status='.($atom!==null?'unchanged':'new').' atomic='.jsBool(count($interfaces)==0).'>');
  // can be hidden with css if necessary (old prototype did not show it)
    
  emit($html, "<div class=AtomName>".htmlSpecialChars($atom).'</div>');
  if (count($interfaces) > 0) {
    emit($html, '<div class=InterfaceList>');
    foreach($interfaces as $interface) {
      emit($html, generateInterface($db, $interface, $atom));
    }
    emit($html, '</div>'); // div class=InterfaceList
  }
  emit($html, '</div>'); // div class=Atom
  return $html;
}

function genSignalLogWindow($roleNr, $roleName) {
  if ($roleNr >= 0) {
    echo "<div class=LogWindow id=SignalLog minimized=false><div class=MinMaxButton></div><div class=Title>Signals for $roleName</div>";
    checkRoleRules($roleNr);
    echo "</div>";
  }
}
?>
