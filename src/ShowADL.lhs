  Deze module bevat de datadefinitie van ADL. Daarnaast bevat het een minimale
  set aan eigenschappen (Eq, Show , Identified) van deze structuren.
  
> module ShowADL ( ShowADL(..) )
> where
>  import CommonClasses(Identified(name))
>  import ADLdataDef
>  import ADLdef (mIs, Morphic(..))
>  import Auxiliaries(chain,showL)

>  class ShowADL a where
>   showADL :: a -> String
>  instance ShowADL a => ShowADL [a] where
>   showADL = chain "\n".map showADL

>  instance ShowADL Architecture where
>   showADL arch = chain "\n" (map showADL (archContexts arch))

>  instance ShowADL Context where
>   showADL context
>    = "CONTEXT " ++name context
>      ++ (if null (ctxon context)   then "" else "EXTENDS "++chain ", "   (ctxon context)                   ++ "\n")
>      ++ (if null (ctxos context)   then "" else "\n"      ++chain "\n\n" (map showADL (ctxos context))   ++ "\n")
>      ++ (if null (ctxcs context)   then "" else "\n"      ++chain "\n"   (map showADL (ctxcs context))   ++ "\n")
>      ++ (if null (ctxds context)   then "" else "\n"      ++chain "\n"   (map showADL (ctxds context))   ++ "\n")
>      ++ (if null (ctxks context)   then "" else "\n"      ++chain "\n"   (map showADL (ctxks context))   ++ "\n")
>      ++ (if null (ctxpats context) then "" else "\n"      ++chain "\n\n" (map showADL (ctxpats context)) ++ "\n")
>      ++ (if null (ctxpops context) then "" else "\n"      ++chain "\n\n" (map showADL (ctxpops context)) ++ "\n")
>      ++ "\n\nENDCONTEXT"
>  --    where decls = declarations context>-declarations (patterns context)
>  --          cdefs = conceptDefs context>-conceptDefs (patterns context)

>  instance ShowADL Pattern where
>   showADL pat
>    = "PATTERN " ++ name pat 
>      ++ (if null (ptrls pat)  then "" else "\n  " ++chain "\n  " (map showADL (ptrls pat)) ++ "\n")
>      ++ (if null (ptgns pat)  then "" else "\n  " ++chain "\n  " (map showADL (ptgns pat)) ++ "\n")
>      ++ (if null (ptdcs pat)  then "" else "\n  " ++chain "\n  " (map showADL (ptdcs pat)) ++ "\n")
>      ++ (if null (ptcds pat)  then "" else "\n  " ++chain "\n  " (map showADL (ptcds pat)) ++ "\n")
>      ++ (if null (ptkds pat)  then "" else "\n  " ++chain "\n  " (map showADL (ptkds pat)) ++ "\n")
>      ++ "ENDPATTERN"

>  instance ShowADL Rule where
>   showADL r@(Sg p rule expla sgn nr pn signal) = "SIGNAL "++name signal++" ON "++ showADL rule
>   showADL r@(Fr _ d expr _) = showADL d ++ "\n" ++ show (name d)++" = "++showADL expr
>   showADL r@(Ru c antc p cons cpu expla sgn nr pn)
>    | c=='A' = "ALWAYS "++showADL cons++
>                 if null cpu then "" else " COMPUTING " ++ show cpu 
>    | c=='I' = showADL antc ++" |- "++showADL cons++
>                 if null cpu then "" else " COMPUTING " ++ show cpu 
>    | c=='E' = showADL antc ++" = " ++showADL cons++
>                 if null cpu then "" else " COMPUTING " ++ show cpu 
>   showADL r@(Gc _ antc cons cpu _ _ _)
>             = "GLUE "++showADL antc++" = "++showADL cons++
>                 if null cpu then "" else " COMPUTING " ++ show cpu

>  instance ShowADL Gen where
>   showADL (G pos g s) = "GEN "++showADL s++" ISA "++show g

>  instance ShowADL ObjectDef where
>   showADL obj = "  OBJECT "++name obj++{-" : I["++(name (target (objctx obj)))++"]"++-}
>                 "\n   = [ "++chain "\n     , " (map (showADL.objctx) (objats obj))++"]"

>  instance ShowADL KeyDef where
>   showADL kd 
>   -- Oorspronkelijk: = "KEY "++kdlbl kd++">"++name (target (kdctx kd))++"("++chain "," (map showADL (kdats kd))++")"
>    = "KEY "++kdlbl kd
>            ++">"++"name (target("++showADL (kdctx kd)++")"
>            ++"("++chain "," (map showADL (kdats kd))++")"

>  instance ShowADL Expression where
>   showADL e = show e

>  instance ShowADL Morphism where
>   showADL m@(Mph nm pos atts sgn@(a,b) yin s)
>    = ({- if take 5 nm=="Clos_" then drop 5 nm++"*" else -} nm)++
>      (if null atts
>           then (if yin && sgn==(decsrc s,dectgt s) || not yin && sgn==(dectgt s,decsrc s) then "" else showSign [a,b])
>           else showSign atts)++
>      if yin then "" else "~"
>   showADL (I atts g s yin)
>    = "I"++if null atts then "" else showSign atts++if g==s then "" else if yin then "" else "~"
>   showADL (V atts (a,b))
>    = "V"++if null atts then "" else showSign atts
>   showADL (Mp1 str sgn)
>    = "'"++str++"'"++(showSign [sgn])
>  showSign cs = "["++chain "*" (map name cs)++"]"

>  instance ShowADL Declaration where
>   showADL decl@(Sgn nm a b props prL prM prR cs expla _ _ sig)
>    = if sig then "SIGNAL "++nm++" ON ("++name a++" * "++name b++")" else
>      nm++" :: "++name a++" * "++name b++
>      (if null props then "" else showL(map showADL props))++
>      (if null(prL++prM++prR) then "" else " PRAGMA "++chain " " (map show [prL,prM,prR]))++
>      (if null expla then "" else " EXPLANATION \""++expla++"\"")
>      ++"."
>   showADL (Isn g s)
>    = "I["++show (name g)++(if g==s then "" else "*"++show (name s))++"]"
>   showADL (Iscompl g s)
>    = "-I["++show (name g)++(if g==s then "" else "*"++show (name s))++"]"
>   showADL (Vs g s)
>    = "V["++show (name g)++(if g==s then "" else "*"++show (name s))++"]"

>  instance ShowADL Prop where
>   showADL p = show p

>  instance ShowADL Population where
>   showADL (Popu m ps)
>    = nlIndent++"pop_"++name m++name (source m)++name (target m)++nlIndent++" = [ "++chain (nlIndent'++"; ") (map show ps)++nlIndent'++"]"
>      where nlIndent = "\n      "; nlIndent' = nlIndent++"    "
>            source (Mph nm pos atts (a,b) yin m) = a
>            target (Mph nm pos atts (a,b) yin m) = b

>  instance ShowADL Concept where
>   showADL c = show (name c)

>  instance ShowADL ConceptDef where
>   showADL cd
>    = "\n  CONCEPT "++show (name cd)++" "++show (cddef cd)++" "++(if null (cdref cd) then "" else show (cdref cd))