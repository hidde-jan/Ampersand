{-# OPTIONS_GHC -Wall #-}
module Prototype.Wrapper (objectWrapper) where
import Strings(chain)
import Adl
import Prototype.RelBinGenBasics(indentBlock,phpIdentifier,commentBlock,addToLast)
import Prototype.RelBinGenSQL(isOne)
import Data.Fspec
import Version (versionbanner)
import Options        (Options(autoid))

--serviceObjects is needed to determine whether some instance of a concept has services to display it i.e. does it become a link
objectWrapper :: Fspc -> [ObjectDef] ->  ObjectDef -> Options -> String
objectWrapper fSpec serviceObjects o flags
 = chain "\n" $
   [ "<?php // generated with "++versionbanner ]
  ++
   commentBlock ["","  Interface V1.3.1","","","  Using interfaceDef",""]
  ++
   [ "  error_reporting(E_ALL); "
   , "  ini_set(\"display_errors\", 1);"
   , "  require \"interfaceDef.inc.php\";"
   , "  require \""++objectName++".inc.php\";"
   , "  require \"connectToDataBase.inc.php\";"
   ]
  ++ --BEGIN: handle save request
   [ "  if(isset($_REQUEST['save'])) { // handle ajax save request (do not show the interface)"]
  ++
   [ "    // we posted . characters, but something converts them to _ (HTTP 1.1 standard)"
   , "    $r=array();"
   , "    foreach($_REQUEST as $i=>$v){"
   , "      $r[join('.',explode('_',$i))]=$v; //convert _ back to ."
   , "    }"
   ]
  ++ --(see phpList2Array below)
   indentBlock 4 (concat [phpList2Array 0 ("$"++phpIdentifier (name a)) (show n) a | (a,n)<-zip (objats o) [(0::Integer)..]])
  ++
   ( if isOne o
     then [ "    $"++objectId++"=new "++objectId++"(" ++ chain ", " ["$"++phpIdentifier (name a) | a<-objats o]++");"
          , "    if($"++objectId++"->save()!==false) die('ok:'."++selfref++");"
          ] 
     else [ "    $"++objectId++"=new "++objectId++"(@$_REQUEST['ID']," ++ chain ", " ["$"++phpIdentifier (name a) | a<-objats o]++");"
          , "    if($"++objectId++"->save()!==false) die('ok:'."++selfref++".'&" ++ objectId ++"='.urlencode($"++objectId++"->getId())"++");"
          ] 
   )
  ++
   [ "    else die('Please fix errors!');"
   , "    exit(); // do not show the interface"
   , "  }" 
   ] --END:handle save request
  ++ 
   [ "  $buttons=\"\";" ]
  ++ --BEGIN:editing + showObjectCode
   indentBlock 2
   ( if isOne o
     then [ "if(isset($_REQUEST['edit'])) $edit=true; else $edit=false;" ]
         ++
          [ "$"++objectId++"=new "++objectId++"();" ]
         ++ indentBlock 2 showObjectCode --(see showObjectCode below)
         ++ 
          [ "if(!$edit) "++
                if elem "Edit" (actions o) 
                then "$buttons.=ifaceButton("++selfref++".\"&edit=1\",\"Edit\");"
                else "$buttons=$buttons;"
          , "else"
          , "  $buttons.=ifaceButton(\"JavaScript:save('\"."++selfref++".\"&save=1');\",\"Save\")"
          , "           .ifaceButton("++selfref++",\"Cancel\");"
          ]
     else [ "if(isset($_REQUEST['new'])) $new=true; else $new=false;"
          , "if(isset($_REQUEST['edit'])||$new) $edit=true; else $edit=false;"
          , "$del=isset($_REQUEST['del']);"
          , "if(isset($_REQUEST['"++objectId++"'])){"
          , "  if(!$del || !del"++objectId++"($_REQUEST['"++objectId++"']))" 
          , "    $"++objectId++" = read"++objectId++"($_REQUEST['"++objectId++"']);"
          , "  else $"++objectId++" = false; // delete was a succes!"
          , "} else if($new) $"++objectId++" = new "++objectId++"();"
          , "else $"++objectId++" = false;"
          ]
         ++
          [ "if($"++objectId++"){" ]
         ++ indentBlock 2 showObjectCode --(see showObjectCode below)
         ++
          [ " if($del) echo \"<P><I>Delete failed</I></P>\";"
          , " if($edit){"
          , "   if($new) "
          , "     $buttons.=ifaceButton(\"JavaScript:save('\"."++selfref++".\"&save=1', document.forms[0].ID.value);\",\"Save\");"
          , "   else { "
          , "     $buttons.=ifaceButton(\"JavaScript:save('\"."++selfref++".\"&save=1','\".urlencode($"++ objectId ++ "->getId()).\"');\",\"Save\");"
          , "     $buttons.=ifaceButton(" ++ selfref1 objectId ++ ",\"Cancel\");"
          , "   } "
          , "} else {"
          , if elem "Edit" (actions o)
            then "        $buttons.=ifaceButton(" ++ selfref2 objectId "edit" ++ ",\"Edit\");"
            else "        $buttons=$buttons;"
          , if elem "Delete" (actions o)
            then "        $buttons.=ifaceButton(" ++ selfref2 objectId "del" ++ ",\"Delete\");"
            else "        $buttons=$buttons;"
          , "       }"
          , "}else{"
          , "  if($del){"
          , "    writeHead(\"<TITLE>Delete geslaagd</TITLE>\");"
          , "    echo 'The "++objectName++" is deleted';"
          , "  }else{  // deze pagina zou onbereikbaar moeten zijn"
          , "    writeHead(\"<TITLE>No "++objectName++" object selected - " ++ appname ++" - ADL Prototype</TITLE>\");"
          , "    ?><i>No "++objectName++" object selected</i><?php "
          , "  }"
          , "  $buttons.=ifaceButton($_SERVER['PHP_SELF'].\"?new=1\",\"New\");"
          , "}"
          ]
   )
  ++
   [ "  writeTail($buttons);"
   , "?>"
   ]
   where
   objectName      = name o
   objectId        = phpIdentifier objectName
   appname         = name fSpec
   showObjectCode --display some concept instance in read or edit mode by definition of SERVICE
    = [ "writeHead(\"<TITLE>"++objectName++" - "++(appname)++" - ADL Prototype</TITLE>\""
      , "          .($edit?'<SCRIPT type=\"text/javascript\" src=\"js/edit.js\"></SCRIPT>':'').'<SCRIPT type=\"text/javascript\""
                ++ " src=\"js/navigate.js\"></SCRIPT>'.\"\\n\" );"
      , "if($edit)"
      , "    echo '<FORM name=\"editForm\" action=\"'.$_SERVER['PHP_SELF'].'\" method=\"POST\" class=\"Edit\">';"
      ]
     ++ --BEGIN: display/edit the identifier of some concept instance
      ( if not (isOne o)
        then ["if($edit && $"++objectId++"->isNew())"
             ,if autoid flags --if not autoid then the user has to come up with an identifier for the new instance
              then "     echo '<H1>New instance of "++objectName++"</H1>';"
              else "     echo '<P><INPUT TYPE=\"TEXT\" NAME=\"ID\" VALUE=\"'.addslashes($"++objectId++"->getId()).'\" /></P>';"
             ,"else echo '<H1>'."++
                  (if null (displaydirective o) 
                   then ("$"++objectId++"->getId()") 
                   else "display('"++displaytbl o++"','"++displaycol o++"',$"++objectId++"->getId())")
                  ++".'</H1>';"
             ,"?>"
             ]
        else ["?><H1>"++objectName++"</H1>"] --the context element is a constant, it is nicer to display the svclabel (objectName)
      ) --END: display/edit the identifier of some concept instance
     ++ concat [attributeWrapper serviceObjects objectId (show n) (length(objats o)>1) a | (a,n)<-zip (objats o) [(0::Integer)..]]
     ++  --(see attributeWrapper below)
      ["<?php"
      ,"if($edit) echo '</FORM>';"
      ]

-----------------------------------------
--some small functions
-----------------------------------------
selfref2::String->String->String
selfref2 objid act = "serviceref($_REQUEST['content'],false,false, array('"++objid++"'=>urlencode($"++objid++"->getId()),'"++act++"'=>1))"
selfref1::String->String
selfref1 objid = "serviceref($_REQUEST['content'],false,false, array('"++objid++"'=>urlencode($"++objid++"->getId()) ))"
selfref::String
selfref = "serviceref($_REQUEST['content'])"
displaydirective::ObjectDef->[(String,String)]
displaydirective obj = [(takeWhile (/='.') x,tail$dropWhile (/='.') x) 
                       | strs<-objstrs obj,('D':'I':'S':'P':'L':'A':'Y':'=':x)<-strs, elem '.' x]
displaytbl::ObjectDef->String
displaytbl obj = fst(head$displaydirective obj)
displaycol::ObjectDef->String
displaycol obj = snd(head$displaydirective obj)

-----------------------------------------
--display/edit the instances related to the identifier of some concept instance (objectId) by definition of SERVICE (att0)
--serviceObjects is nodig voor GoToPages
-- "$" ++ objectId is de instantie van de class die je op het scherm ziet
--path0 is een op atts gezipt nummertje. Er wordt een wrapper gemaakt voor iedere [wrapper (show n) att0|(att0,n)<-atts o]
--siblingatt0s bepaalt of er meer dan 1 (wrapper att0) is. Deze info is nodig om te bepalen of CLASS = '.. UI of UI_*'.
--att0 is de huidige subservice
attributeWrapper::[ObjectDef]->String->String->Bool->ObjectDef->[String]
attributeWrapper serviceObjects objectId path0 siblingatt0s att0
 = let 
   cls0 | siblingatt0s = "_"++phpIdentifier (name att0) 
        | otherwise    = ""
   content = attContent ("$"++phpIdentifier (name att0)) (0::Integer) path0 cls0 att0
   newBlocks = attEdit ("$"++phpIdentifier (name att0)) (0::Integer) path0 cls0 att0
   in
   --BEGIN : content (in read or edit mode)
   if elem "PICTURE" [x|xs<-objstrs att0,x<-xs] 
   --TODO-> replace by checking (target att0)==Cpt "Picture" && Picture ISA Datatype
   --The meaning of and the concept name "Datatype" is claimed by Ampersand.
   --The meaning of and the concept name "String" is claimed by Ampersand. (GEN String ISA Datatype)
   --other specific datatypes have to be declared to get the Ampersand meaning e.g. GEN Picture ISA Datatype
   --the Ampersand meaning of Picture is that its value (value::Picture->String[INJ].) is an URL string
   --we could define GEN URL ISA String and declare rules for URL's
   --TODO -> Pictures are presented the same in read and edit mode (not editable) => develop class(es) for pictures
   then --in Atlas.adl GEN Picture ISA Datatype is needed instead of the current default GEN String ISA Datatype
   [ "<?php"
   , "      $"++ phpIdentifier (name att0) ++" = $" ++ objectId ++ "->get_" ++ phpIdentifier (name att0)++"();"
   ]
   ++ indentBlock 6 (embedimage att0 0) --(see embedimage below)
   ++
   [ "    ?> "]
   else
   [ "<DIV class=\"Floater "++(name att0)++"\">"
   , "  <DIV class=\"FloaterHeader\">"++(name att0)++"</DIV>"
   , "  <DIV class=\"FloaterContent\"><?php"
   , "      $"++ phpIdentifier (name att0) ++" = $" ++ objectId ++ "->get_" ++ phpIdentifier (name att0)++"();" --read instance from DB
   ] 
   ++ indentBlock 6 content --(see attContent below)
   ++
   [ "    ?> "
   , "  </DIV>"
   , "</DIV>"
   ] --END: content
   ++ --BEGIN: edit blocks (see attEdit below)
   if null newBlocks then [] 
   else
   [ "<?php if($edit){ ?>"
   , "<SCRIPT type=\"text/javascript\">"
   , "  // code for editing blocks in "++(name att0)
   ]
   ++ indentBlock 2 (concat [showBlockJS c a | (c,a)<-newBlocks])
   ++
   [ "</SCRIPT>"
   , "<?php } ?>"
   ] --END: edit blocks
   where    
   -----------------------------------------
   --CONTENT functions
   -----------------------------------------
   --the content for an att0 has already been read in a class instance for this service
   -- recall: $"++ phpIdentifier (name att0) ++" = $" ++ objectId ++ "->get_" ++ phpIdentifier (name att0)++"();"
   --content enters at attContent with 
   --   att=att0
   --   var=("$"++phpIdentifier (name att0))
   --   depth=(0::Integer),path=path0,cls=cls0
   --attContent makes a suitable frame based on the multiplicity of (objctx att)
   --depth increases with 1 iff not(UNI), this should sync with phpList2Array (saving request) and attEdit (javascript functions) for synced paths
   --uniAtt prints the values as links in read mode and as values in edit mode
   --if there are objats, then the instances on this level are printed as headers with links
   --through attHeaders the recursion of attContent is made with
   --   att'= a
   --   var'=(var++"['"++name a++"']")
   --   path'=(path++"."++show n)
   gotoPages :: ObjectDef->String->[(String,String)]
   gotoPages att idvar
     = [ ("'.serviceref('"++name serv++"',false,$edit, array('"++(phpIdentifier$name serv)++"'=>urlencode("++idvar++"))).'"
         ,name serv)
       | serv<-serviceObjects
       , target (objctx serv) == target (objctx att)
       ]
   gotoPagesNew :: ObjectDef->[(String,String)]
   gotoPagesNew att
     = [ ("'.serviceref('"++name serv++"',$edit).'"
         ,name serv)
       | serv<-serviceObjects
       , target (objctx serv) == target (objctx att)
       ]
   gotoDiv gotoP path
    = [ "echo '<DIV class=\"Goto\" id=\"GoTo"++path++"\"><UL>';"] ++
      [ "echo '<LI><A HREF=\""++link++"\">"++txt++"</A></LI>';"
      | (link,txt) <- gotoP] ++
      [ "echo '</UL></DIV>';" ]
   gotoDivNew gotoP path
    = [ "echo '<DIV class=\"Goto\" id=\"GoTo"++path++"\"><UL>';"] ++
      [ "echo '<LI><A HREF=\""++link++"\">new "++txt++"</A></LI>';"
      | (link,txt) <- gotoP] ++
      [ "echo '</UL></DIV>';" ]
   ----------------
   -- attContent shows a list of values, using uniAtt if it is only one
   attContent var depth path cls att 
    | not (isUni (objctx att)) --(not(UNI) with or without objats) 
      = let
        content = uniAtt atnm idvar (depth+1) (path ++".'.$i"++show depth++".'") cls att
        atnm = if "$"++phpIdentifier (name att)==var then "$v"++show depth else "$"++phpIdentifier (name att)
        idvar = if "$"++phpIdentifier (name att)==var then "$idv"++show depth else "$id"++phpIdentifier (name att)
        gotoP = gotoPagesNew att
        in
        [ "echo '"
        , "<UL>';"
        , "foreach("++var++" as $i"++show depth++"=>"++idvar ++"){"
        , --atnm is set to I(idvar) or value(idvar), where value is the name of the display relation
          "  "++atnm ++"="++(if null (displaydirective att) then idvar
                       else (if null(objats att)
                             then "display('"++displaytbl att++"','"++displaycol att++"',"++idvar++")"
                             else idvar)) ++ ";" 
        , "  echo '"
        , "  <LI CLASS=\"item UI"++cls++"\" ID=\""++(path ++".'.$i"++show depth++".'")++"\">';"
        , if null(objats att) || null(displaydirective att) 
          then [] 
          else "  echo display('"++displaytbl att++"','"++displaycol att++"',"++idvar++"['id']);"
        ]
        ++ indentBlock 4 content ++
        [ "  echo '</LI>';"
        , "}"
        ]
      --  , "  <A HREF=\"'.serviceref('Obj',$edit).'">new Obj</A>';"
        ++
        (if null gotoP --TODO new UI should become a dropdown to create a new relation instance, including <new concept instance> which are links (gotoP)
         then   [ "if($edit) echo '"
                , "  <LI CLASS=\"new UI"++cls++ "\" ID=\""++(path ++".'.count("++var++").'")++"\">enter instance of "++name att++"</LI>';"]
         else 
          (if length gotoP == 1
           then [ "if($edit) echo '" --TODO so these LI's should become one dropdown
                , "  <LI CLASS=\"new UI"++cls++ "\" ID=\""++(path ++".'.count("++var++").'")++"\">enter instance of "++name att++"</LI>"
                , "  <LI CLASS=\"newlink UI"++cls++ "\" ID=\""++(path ++".'.(count("++var++")+1).'")++"\">"
                , "    <A HREF=\""++(fst$head gotoP)++"\">new instance of "++name att++"</A>"
                , "  </LI>';" ]
           else [ "if($edit) {" --TODO and these LI's should become one dropdown too
                , "  echo '<LI CLASS=\"new UI"++cls++ "\" ID=\""++(path ++".'.count("++var++").'")++"\">enter instance of "++name att++"</LI>';"
                , "  echo '<LI CLASS=\"newlink UI"++cls++ "\" ID=\""++(path ++".'.(count("++var++")+1).'")++"\">';"
                , "  echo '<A class=\"GotoLink\" id=\"To"++path++"\">new instance of "++name att++"</A>';"]
               ++ indentBlock 2 (gotoDivNew gotoP path) ++
                [ "  echo '</LI>';"
                , "}" ]
-- <DIV class="GotoArrow" id="To0">
--   new Obj
-- </DIV>
-- <DIV class="Goto" id="GoTo0">
--   <UL>
--    <LI><A HREF="ctxSimple.php?content=Obj&new=1">new Obj</A></LI>
--    <LI><A HREF="ctxSimple.php?content=OtherSvcForObj&new=1">new OtherSvcForObj</A></LI>
--   </UL>
-- </DIV>
--
-- <LI CLASS="item UI" ID="0.0">
--            <A class="GotoLink" id="To0.0">ObjX</A>
--            <DIV class="Goto" id="GoTo0.0">
--              <UL>
--                <LI><A HREF="ctxSimple.php?content=Obj&Obj=ObjX">Obj</A></LI>
--                <LI><A HREF="ctxSimple.php?content=OtherSvcForObj&OtherSvcForObj=ObjX">OtherSvcForObj</A></LI>
--              </UL>
--             </DIV>
-- </LI>
 

          )
        )
        ++
        [ "echo '"
        , "</UL>';"
        ]
    | objats att==[] --attContent (UNI without objats)
      = let
        content = uniAtt (dvar var) var depth path cls att
    --       spanordiv = if isTot (objctx att) then "SPAN" else "DIV"
        dvar var'@('$':x) = if null (displaydirective att) then var' else ('$':("display"++x))
        dvar x = x
        in
        if isTot (objctx att)
        then  [ "echo '<SPAN CLASS=\"item UI"++cls++"\" ID=\""++path++"\">';" 
              , "  "++dvar var ++"="++(if null (displaydirective att) then var 
                       else "display('"++displaytbl att++"','"++displaycol att++"',"++var++")") ++ ";"]
             ++ content ++ [ "echo '</SPAN>';" ]
        else  [ "if (isset("++var++")){"
              , "  "++dvar var ++"="++(if null (displaydirective att) then var 
                       else "display('"++displaytbl att++"','"++displaycol att++"',"++var++")") ++ ";"
              , "  echo '<DIV CLASS=\"item UI"++cls++"\" ID=\""++path++"\">';"
              , "  echo '</DIV>';"] ++ indentBlock 2 content ++
              [ "} else echo '<DIV CLASS=\"new UI"++cls++"\" ID=\""++path++"\"><I>Nothing</I></DIV>';"
              ]
    | (isTot(objctx att)) --attContent (UNI & TOT with objats)
      = let
        content = uniAtt (var) var depth path cls att
        in
        [ "echo '<DIV CLASS=\"UI"++cls++"\" ID=\""++path++"\">';" ]
        ++ indentBlock 2 content ++
        [ "echo '</DIV>';" ]
    | otherwise --attContent (UNI & not(TOT) with objats)
      = let
        content = uniAtt (var) var depth path cls att
        in
        [ "if(isset("++var++")){"
         , "  echo '<DIV CLASS=\"item UI"++cls++"\" ID=\""++path++"\">';"]
         ++ indentBlock 4 content ++
         [ "  echo '</DIV>';"
         , "}else{"
         , "  echo '<DIV CLASS=\"new UI"++cls++"\" ID=\""++path++"\"><I>Nothing</I></DIV>';"
         , "}"]    
   ----------------end: attContent
   uniAtt var idvar depth path cls att
    | null (objats att)
      = let
        content=if null gotoP || isIdent (ctx att) then ["echo "++echobit++";"]
                else if length gotoP == 1
                     then ["if(!$edit) echo '"
                          ,"<A HREF=\""++(fst$head gotoP)++"\">'."++echobit++".'</A>';"
                          ,"else echo "++echobit++";"]
                     else ["if(!$edit){"
                          ,"  echo '"
                          ,"<A class=\"GotoLink\" id=\"To"++path++"\">';"
                          ,"  echo "++echobit++".'</A>';"]
                          ++ indentBlock 2 (gotoDiv gotoP path) ++
                          [ "} else echo "++echobit++";" ]
        echobit= "htmlspecialchars("++var++")"
        gotoP = gotoPages att idvar
        in
        if not (isTot (objctx att)) && isUni (objctx att)
        then [ "if(isset("++var++")){" ] ++ indentBlock 2 content ++ ["}"]
        else ["if("++var++"==''){echo 'nothing';}", "else{"] ++ content ++ ["}"]
    | otherwise --uniAtt
      = let
        gotoP = gotoPages att (idvar ++ "['id']")
        content 
         = [ indentBlock 2 c
           | (a,n)<-zip (objats att) [(0::Integer)..]
           , c<-[attHeading (var++"['"++name a++"']") depth (path++"."++show n)
                                (cls ++ if length(objats att) > 1
                                        then (if null cls then "" else "_")
                                             ++ phpIdentifier (name a)
                                        else "") a]]
        in
        (if null gotoP then []
         else if length gotoP == 1
              then [ "if(!$edit){"
                   , "  echo '"
                   , "<A HREF=\""++(fst$head gotoP)++"\">';"
                   , "  echo '<DIV class=\"GotoArrow\">&rarr;</DIV></A>';"
                   , "}" ]
              else [ "if(!$edit){"
                   , "  echo '"
                   , "<DIV class=\"GotoArrow\" id=\"To"++path++"\">&rArr;</DIV>';"]
                   ++ indentBlock 2 (gotoDiv gotoP path) ++
                   [ "}" ]
        )++
        ["echo '"
        ,"<DIV>';"]
        ++ chain ["echo '</DIV>"
                 ,"<DIV>';"] content
        ++ ["echo '"
           ,"</DIV>';"
           ,"if($edit) echo '"
           ,"<INPUT TYPE=\"hidden\" name=\""++path++".ID\" VALUE=\"'."++var++"['id'].'\" />';"
           ]
   -----------end: uniAtt
   -- attHeading shows a heading and its value
   attHeading var depth path cls att 
    | objats att==[]
      = ["echo '"++name att++": ';"] ++ content
    | otherwise
      = [ "?> "
        , "<DIV class =\"Holder\"><DIV class=\"HolderHeader\">"++(name att)++"</DIV>"
        , "  <DIV class=\"HolderContent\" name=\""++(name att)++"\"><?php"
        ] ++ indentBlock 6 content ++
        [ "    ?> "
        , "  </DIV>"
        , "</DIV>"
        , "<?php"
        ]
      where content = attContent var depth path cls att
----------------------
--display one or more pictures, assumed to be behind their url values (GEN Picture ISA Datatype)
embedimage::ObjectDef->Integer->[String]
embedimage att depth
  = if isUni(objctx att)
    then ["echo '<IMG src=\"'.$"++ phpIdentifier (name att) ++".'\"/>';"]
    else ["foreach($"++phpIdentifier (name att)++" as $i"++show depth++"=>$v"++show depth++"){"
         , "  echo '<IMG src=\"'.$v"++show depth++".'\"/>';"
         , "}"]

-----------------------------------------
--EDIT BLOCK functions
-----------------------------------------
showBlockJS::String->ObjectDef->[String]
showBlockJS cls att
 = [ "function UI"++cls++"(id){"
   , "  return " ++ head attCode'] ++ (map ((++) "       + ") (tail attCode')) ++
   [ "        ;", "}"]
   where
     attCode' = map (\x->"'"++x++"'") (attCode "'+id+'." cls att)
     attCode strt c at = ["<DIV>"++(name a)++": "++(specifics c (strt ++ show n) a)++"</DIV>"
                         | (n,a)<-zip [(0::Integer)..] (objats at)]
     specifics c n a = if isUni (objctx a)
                         then if isTot (objctx a)
                              then "<SPAN CLASS=\"item UI"++acls c a++"\" ID=\""++n
                                   ++"\">" ++ concat (attCode n (acls c a) a) ++"</SPAN>"
                              else "<DIV CLASS=\"new UI"++acls c a++"\" ID=\""
                                   ++n++"\"><I>Nothing</I></DIV>"
                         else "<UL><LI CLASS=\"new UI"++acls c a
                              ++"\" ID=\""++n++"\">new "++(name a)++"</LI></UL>"
     acls c a = c++"_"++(phpIdentifier (name a))
-------------
uniEditAtt::String->Integer->String->String->ObjectDef->[(String,ObjectDef)]
uniEditAtt var depth path cls att
  | null (objats att) = []
  | otherwise = concat 
       [ b | (a,n)<-zip (objats att) [(0::Integer)..]
           , b<-[attEdit (var++"['"++name a++"']") --(TODO: vgl. UniContentAtt)
                depth
                (path++"."++show n) 
                (cls ++ if length(objats att) > 1
                        then (if null cls then "" else "_") ++ phpIdentifier (name a)
                        else "")
                a]
       ]
attEdit::String->Integer->String->String->ObjectDef->[(String,ObjectDef)]
attEdit var depth path cls att 
 | not (isUni (objctx att))
   = let
     newBlocks = uniEditAtt atnm (depth+1) (path ++".'.$i"++show depth++".'") cls att
     atnm = if "$"++phpIdentifier (name att)==var then "$v"++show depth else "$"++phpIdentifier (name att)
     in
     (if null (objats att) then [] else [(cls,att)]) ++ newBlocks
 | objats att==[] = []
 | (isTot(objctx att)) = uniEditAtt var depth path cls att
 | otherwise 
   = let 
     newBlocks = uniEditAtt var depth path cls att
     tot = (isTot(objctx att))
     in 
     (if tot then [] else [(cls,att)]) ++ newBlocks

-----------------------------------------
--PHP wrapper page functions
-----------------------------------------
--phpList2Array is used once in objectWrapper:
--indentBlock 4 (concat [phpList2Array 0 ("$"++phpIdentifier (name a)) (show n) a | (a,n)<-zip (objats o) [(0::Integer)..]])
phpList2Array :: Int->String->String->ObjectDef->[String]
phpList2Array depth var rqvar a
 = if not (isUni (objctx a))
   then [ var++"=array();"
        , "for($i"++show depth++"=0;isset($r['"++rqvar++".'.$i"++show depth++"]);$i"
               ++show depth++"++){"]
        ++ indentBlock 2 (phpList2ArrayUni (depth+1)
                                           (var++"[$i"++show depth++"]")
                                           (rqvar++".'.$i"++show depth++".'")
                                           a
                         ) ++
        [ "}"]
   else if not (isTot (objctx a))
        then ["if(@$r['"++rqvar++"']!=''){"]
             ++ indentBlock 2 (phpList2ArrayUni depth var rqvar a) ++
             ["}else "++var++"=null;"]
        else (phpList2ArrayUni depth var rqvar a)
phpList2ArrayUni :: Int -> String->String->ObjectDef->[String]
phpList2ArrayUni depth var rqvar a
 = addToLast ";" ([ var++" = "++head (phpList2ArrayVal var rqvar a)]  ++
                  indentBlock (8 + length var) (tail (phpList2ArrayVal var rqvar a))
                 ) ++
   concat
   [ phpList2Array depth (var++"['"++name a'++"']") (rqvar++"."++show n) a'
   | (a',n)<-zip (objats a) [(0::Integer)..],not (isUni (objctx a'))]
phpList2ArrayVal :: String->String->ObjectDef->[String]
phpList2ArrayVal var rqvar a
 = if null (objats a) then ["@$r['"++rqvar++"']"]
   else [ "array( 'id' => @$r['"++rqvar'++"']"] ++ 
        [ ", '" ++ name a' ++ "' => "
          ++ concat (phpList2ArrayVal var (rqvar++'.':show n) a')
        | (a',n)<-zip (objats a) [(0::Integer)..], isUni (objctx a')] ++
        [ ")"]
         -- we gebruiken voor rqvar' liever iets waarvan het attribuut ingesteld wordt:
   where rqvar' = head ( [(rqvar++'.':show n)
                         | (a',n)<-zip (objats a) [(0::Integer)..]
                         , isUni (objctx a')
                         , isIdent (objctx a')
                         ] ++ [rqvar] )
----------------------------
