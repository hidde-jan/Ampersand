module Database.Design.Ampersand.FSpec.SQL
  (selectSrcTgt,QueryExpr
  ,prettySQLQuery
  , selectExprRelation  --exported to be able to validate the generated SQL for individual relations
  )
  
where


import Language.SQL.SimpleSQL.Syntax
import Language.SQL.SimpleSQL.Pretty
import Database.Design.Ampersand.Basics
import Database.Design.Ampersand.Classes.ConceptStructure
import Database.Design.Ampersand.Core.AbstractSyntaxTree
import Database.Design.Ampersand.ADL1.Expression
import Database.Design.Ampersand.Classes.Relational
import Database.Design.Ampersand.FSpec.FSpec
import Database.Design.Ampersand.FSpec.FSpecAux
import Database.Design.Ampersand.FSpec.ShowADL

import Data.Char
import Data.List
import Data.Maybe

fatal :: Int -> String -> a
fatal = fatalMsg "FSpec.SQL"

-- | prettyprint ValueExpr and indent it with spaces
prettySQLQuery :: Int -> QueryExpr -> String
prettySQLQuery i =  intercalate ("\n"++replicate i ' ') .  lines . prettyQueryExpr

selectSrcTgt :: 
           FSpec       -- current context
        -> Expression  -- expression to be translated
        -> QueryExpr   -- resulting SQL expression
selectSrcTgt fSpec expr = toSQL (selectExpr fSpec sourceAlias targetAlias expr)


sourceAlias, targetAlias :: Name
sourceAlias = (Name "src") 
targetAlias = (Name "tgt")
selectExpr :: FSpec    -- current context
        -> Name        -- SQL name of the source of this expression, as assigned by the environment
        -> Name        -- SQL name of the target of this expression, as assigned by the environment
        -> Expression  -- expression to be translated
        -> BinQueryExpr   -- resulting info for the binary SQL expression
-- In order to translate all Expressions, code generators have been written for EUni ( \/ ), EIsc ( /\ ), EFlp ( ~ ), ECpl (unary - ), and ECps ( ; ),
-- each of which is supposed to generate correct code in 100% of the cases. (TODO: how do we establish that properly?)
-- The other operators, EEqu ( = ), EImp ( |- ), ERad ( ! ), EPrd ( * ), ELrs ( / ), ERrs ( \ ), and EDia ( <> ), have been implemented in terms of the previous ones,
-- in order to prevent mistakes in the code generator. It is possible that more efficient code may be generated in these cases.
-- Special cases are treated up front, so they will overrule the more general cases.
-- That allows more efficient code while retaining correctness and completeness as much as possible.
-- Code for the Kleene operators EKl0 ( * ) and EKl1 ( + ) is not done, because this cannot be expressed in SQL.
-- These operators must be eliminated from the Expression before using selectExpr, or else you will get fatals.
selectExpr fSpec src trg expr
 = case expr of
    EIsc{} -> 
    {- The story on the case of EIsc:
 This alternative of selectExpr compiles a conjunction of at least two subexpressions (code: EIsc lst'@(_:_:_))
 Each of these subexpressions are of one of the following types:
     1) positive and Mp1
     2) negative and Mp1
     3) not Mp1
    -}
          case posVals of
            ( _ {-a-} : _ {-b-} : _ )
                -> emptySet  --since a /= b, there can be no result. 
            [val]
                -> if val `elem` negVals then emptySet
                   else f (Just val) nonMp1Terms
            []  -> f Nothing nonMp1Terms
           where 
                  posVals :: [String]
                  posVals = nub (map atmValue posMp1Terms)
                  negVals :: [String]
                  negVals = nub (map (atmValue . notCpl) negMp1Terms)
                  atmValue (EMp1 a _) = a
                  atmValue _          = fatal 31 "atm error"
                  mp1Terms, nonMp1Terms :: [Expression]
                  (mp1Terms,nonMp1Terms) = partition isMp1 (exprIsc2list expr)
                  posMp1Terms, negMp1Terms :: [Expression]
                  (posMp1Terms,negMp1Terms) = partition isPos mp1Terms
                  f :: Maybe String   -- Optional the single atomvalue that might be found as the only possible value 
                      -> [Expression] -- subexpressions of the intersection.  Mp1{} nor ECpl(Mp1{}) are allowed elements of this list.  
                      -> BinQueryExpr
                  f specificValue subTerms 
                     = case subTerms of
                          [] -> case specificValue of 
                                 Nothing  -> emptySet -- case might occur with only negMp1Terms??
                                 Just str ->
                                    BSE { bseCmt = "case: (EIsc "++showADL expr++" ("++show (sign expr)++")"
                                        , bseSrc = StringLit str
                                        , bseTrg = StringLit str
                                        , bseTbl = []
                                        , bseWhr = Nothing
                                        }
                          ts  ->   BSE { bseCmt = "case: (EIsc "++showADL expr++" ("++show (sign expr)++")" 
                                        , bseSrc = theSrc
                                        , bseTrg = theTrg
                                        , bseTbl = theTbl
                                        , bseWhr = case catMaybes [mandatoryTuple,forbiddenTuples,theWhr] of
                                                    [] -> Nothing
                                                    vs -> Just (conjunctSQL vs)
                                        }
                                     where
                                       mandatoryTuple :: Maybe ValueExpr
                                       mandatoryTuple =
                                          case specificValue of
                                            Nothing  -> Nothing
                                            Just val -> Just $ equalToValueClause val
                                          where
                                            equalToValueClause :: String -> ValueExpr
                                            equalToValueClause str = conjunctSQL 
                                                               [ BinOp theSrc [Name "="] (StringLit str)
                                                               , BinOp theTrg [Name "="] (StringLit str)
                                                               ]

                                       forbiddenTuples :: Maybe ValueExpr
                                       forbiddenTuples = 
                                           case negVals of
                                            []  -> Nothing
                                            _   -> Just . conjunctSQL $
                                                     map notEqualToValueClause negVals
                                          where
                                            notEqualToValueClause :: String -> ValueExpr
                                            notEqualToValueClause str = conjunctSQL 
                                                               [ BinOp theSrc [Name "<>"] (StringLit str)
                                                               , BinOp theTrg [Name "<>"] (StringLit str)
                                                               ]

                                       theSrc = bseSrc (makeSelectable sResult)
                                       theTrg = bseTrg (makeSelectable sResult)
                                       theTbl = bseTbl (makeSelectable sResult)
                                       theWhr = bseWhr (makeSelectable sResult)
                                       sResult = makeIntersectSelectExpr ts
                                       makeSelectable :: BinQueryExpr -> BinQueryExpr
                                       makeSelectable x =
                                         case x of
                                           BSE{}   -> x
                                           BCQE{}  -> BSE { bseCmt = ""
                                                          , bseSrc = Iden [sourceAlias]
                                                          , bseTrg = Iden [targetAlias]
                                                          , bseTbl = [TRParens . TRQueryExpr . toSQL $ x]
                                                          , bseWhr = Nothing
                                                          }
                                       makeIntersectSelectExpr :: [Expression] -> BinQueryExpr
                                       makeIntersectSelectExpr exprs =
                                        case map (selectExpr fSpec sourceAlias targetAlias) exprs of 
                                          []  -> fatal 126 "makeIntersectSelectExpr must not be used on empty list"
                                          [e] -> e
                                          es  -> -- Note: We now have at least two subexpressions
                                                 BSE { bseCmt = "`intersect` does not work in MySQL, so this statement is generated:"
                                                     , bseSrc = Iden[iSect 0,sourceAlias]
                                                     , bseTrg = Iden[iSect 0,targetAlias]
                                                     , bseTbl = map tableRef (zip [0..] es)
                                                     , bseWhr = Just . conjunctSQL . concatMap constraintsOfTailExpression $ 
                                                                   [1..length (tail es)]     
                                                     }
                                                  where
                                                   iSect :: Int -> Name
                                                   iSect n = Name ("subIntersect"++show n)
                                                   tableRef :: (Int, BinQueryExpr) -> TableRef
                                                   tableRef (n, e) = TRQueryExpr (toSQL e) `as` iSect n
                                                   constraintsOfTailExpression :: Int -> [ValueExpr]
                                                   constraintsOfTailExpression n 
                                                      = [ BinOp (Iden[iSect n,sourceAlias]) [Name "="] (Iden[iSect 0,sourceAlias])
                                                        , BinOp (Iden[iSect n,targetAlias]) [Name "="] (Iden[iSect 0,targetAlias])
                                                        ]
--                                          (e:es) -> BCQE { bcqeCmt  = "intersect case"
--                                                         , bcqeOper = Intersect
--                                                         , bcqe0    = selectExpr fSpec sourceAlias targetAlias e
--                                                         , bcqe1    = makeIntersectSelectExpr es
--                                                         }

    EUni (l,r) -> BCQE { bcqeCmt  = "case: EUni (l,r)"++showADL expr++" ("++show (sign expr)++")"
                       , bcqeOper = Union
                       , bcqe0    = selectExpr fSpec src trg l
                       , bcqe1    = selectExpr fSpec src trg r
                       }
    
    
    ECps (EDcV (Sign ONE _), ECpl expr')
     -> case target expr' of
         ONE -> fatal 137 "sqlConcept not defined for ONE"
         _   -> let src'  = sqlAttConcept fSpec (source expr')
                    trg'  = sqlAttConcept fSpec (target expr')
                    trg2  = noCollide' [src'] (sqlAttConcept fSpec (target expr'))
                    allAtoms = Name "allAtoms"
                    complemented = Name "complemented"
                in BSE { bseCmt = "case:  ECps (EDcV (Sign ONE _), ECpl expr') "++showADL expr
                       , bseSrc = NumLit "1"
                       , bseTrg = Iden [trg'    ]
                       , bseTbl = [sqlConceptTable fSpec (target expr') `as` allAtoms]
                       , bseWhr = Just $ selectNotExists 
                                           [selectExprInFROM fSpec src' trg' expr' `as` complemented]
                                           (Just (BinOp (Iden [complemented,trg2])
                                                          [Name "="]
                                                        (Iden [allAtoms,trg'])
                                                 )
                                           )
                       }
                                 
    ECps{}  ->
       case exprCps2list expr of
          (EDcV (Sign ONE _):fs@(_:_))
             -> let expr' = foldr1 (.:.) fs
                    src'  = noCollide' [trg'] (sqlExprSrc fSpec expr')
                    trg'  = sqlExprTgt fSpec expr'
                in 
                 BSE { bseCmt = "case:  (EDcV (Sign ONE _): fs@(_:_))"++showADL expr
                     , bseSrc = NumLit "1"
                     , bseTrg = Iden [QName "fst",trg'    ]
                     , bseTbl = [selectExprInFROM fSpec src' trg' expr' `as` QName "fst"]
                     , bseWhr = (Just (notNull (Iden [QName "fst", trg'])))
                     }
                
          (s1@EMp1{}: s2@(EDcV _): s3@EMp1{}: fx@(_:_)) -- to make more use of the thing below
             -> sqlcomment ("case:  (s1@EMp1{}: s2@(EDcV _): s3@EMp1{}: fx@(_:_))"
                            ++showADL expr)
                (selectExpr fSpec src trg (foldr1 (.:.) [s1,s2,s3] .:. foldr1 (.:.) fx))
          [EMp1 atomSrc _, EDcV _, EMp1 atomTgt _]-- this will occur quite often because of doSubsExpr
             -> BSE { bseCmt = "case:  [EMp1 atomSrc _, EDcV _, EMp1 atomTgt _]"++showADL expr
                    , bseSrc = sqlAtomQuote atomSrc
                    , bseTrg = sqlAtomQuote atomTgt
                    , bseTbl = []
                    , bseWhr = Nothing
                    }
          (e@(EMp1 atom _):f:fx)
             -> let expr' = foldr1 (.:.) (f:fx)
                    src' = sqlExprSrc fSpec e
                    trg' = noCollide' [src'] (sqlExprTgt fSpec expr')
                in 
                 BSE { bseCmt = "case:  (EMp1{}: f: fx)"++showADL expr
                     , bseSrc = Iden [QName "fst",src']
                     , bseTrg = Iden [QName "fst",trg']
                     , bseTbl = [selectExprInFROM fSpec src' trg' expr' `as` QName "fst"]
                     , bseWhr = (Just (BinOp (Iden [QName "fst",src'])
                                             [Name "="]
                                             (sqlAtomQuote atom)))
                     }
          (e:EDcV _:f:fx) -- prevent calculating V in this case
             | src==trg && not (isProp e) -> fatal 172 $ "selectExpr 2 src and trg are equal ("++stringOfName src++") in "++showADL e
             | otherwise -> let expr' = foldr1 (.:.) (f:fx)
                                src' = sqlExprSrc fSpec e
                                mid' = noCollide' [src'] (sqlExprTgt fSpec e)
                                mid2'= sqlExprSrc fSpec f
                                trg' = noCollide' [mid2'] (sqlExprTgt fSpec expr')
                            in 
                             BSE { bseCmt = "case:  (e:ERel (EDcV _) _:f:fx)"++showADL expr
                                 , bseSrc = Iden [QName "fst",src']
                                 , bseTrg = Iden [QName "snd",trg']
                                 , bseTbl = [selectExprInFROM fSpec src' mid' e      `as` QName "fst"
                                            ,selectExprInFROM fSpec mid2' trg' expr' `as` QName "snd"
                                            ]
                                 , bseWhr = Nothing
                                 }
          [] -> fatal 190 ("impossible outcome of exprCps2list: "++showADL expr)
          [e]-> selectExpr fSpec src trg e -- Even though this case cannot occur, it safeguards that there are two or more elements in exprCps2list expr in the remainder of this code.
{-  We can treat the ECps expressions as poles-and-fences, with at least two fences.
    Imagine subexpressions as "fences". The source and target of a "fence" are the "poles" between which that "fence" is mounted.
    In this metaphor, we create the FROM-clause directly from the "fences", and the WHERE-clause from the "poles" between "fences".
    The "outer poles" correspond to the source and target of the entire expression.
    To prevent name conflicts in SQL, each subexpression is aliased in SQL by the name "ECps<n>".
SELECT DISTINCT ECps0.`C` AS `SrcC`, ECps0.`A` AS `TgtA`
FROM `r` AS ECps0, `A`AS ECps2
WHERE ECps0.`A`<>ECps2.`A
-}
          es -> let fenceName :: Int -> Name
                    fenceName n = Name ("subComposit"++show n)
                    firstNr, lastNr :: Int
                    firstNr = 0
                    lastNr = firstNr + length es - 1
                    fences :: [(Int, TableRef)]
                    fences = map makeFence (zip [firstNr..lastNr] es)
                      where makeFence :: (Int, Expression) -> (Int, TableRef)
                            makeFence (i,e) = (i, (TRQueryExpr . toSQL) (selectExpr fSpec sourceAlias targetAlias e) `as` fenceName i)
                    -- | the equivalence expression between fence n-1 and fence n (both must exist, which holds for n in [firstNr + 1 .. lastNr] ) 
                    poleEquivalence :: Int -> ValueExpr
                    poleEquivalence n = BinOp (Iden [fenceName (n-1),targetAlias])
                                              [Name "="]
                                              (Iden [fenceName n    ,sourceAlias])
                in BSE { bseCmt = "case: (ECps es), with two or more elements in es."++showADL expr
                       , bseSrc = Iden [fenceName firstNr,sourceAlias]
                       , bseTrg = Iden [fenceName lastNr, targetAlias]
                       , bseTbl = map snd fences
                       , bseWhr = case map poleEquivalence [firstNr + 1 .. lastNr] of
                                    []   -> Nothing
                                    whrs -> Just . conjunctSQL $ whrs
                       }
    (EFlp x) -> case selectExpr fSpec src trg x of
                 se@BSE{} -> BSE { bseCmt = "(flipped): "++ bseCmt se
                                 , bseSrc = bseTrg se
                                 , bseTrg = bseSrc se
                                 , bseTbl = bseTbl se
                                 , bseWhr = bseWhr se
                                 }
                 BCQE {bcqeOper=oper} -> fatal 313 $ "Unexpected: Directly flip a `"++show oper++"` expression. (What happend to the brackets?)"
    (EMp1 atom _) -> BSE { bseCmt = "case: EMp1 atom."
                         , bseSrc = sqlAtomQuote atom
                         , bseTrg = sqlAtomQuote atom
                         , bseTbl = []
                         , bseWhr = Nothing
                         }
    (EDcV (Sign s t))    -> sqlcomment ("case: (EDcV (Sign s t))   V[ \""++show (Sign s t)++"\" ]") $
                            let (psrc,fsrc) = getConceptTableInfo fSpec s
                                (ptgt,ftgt) = getConceptTableInfo fSpec t
                                (src1,trg1,tbl1) 
                                  = case (s,t) of
                                       (ONE, ONE) -> ( NumLit "1"
                                                     , NumLit "1"
                                                     , []
                                                     )
                                       (_  , ONE) -> ( Iden [QName (name psrc),QName (name fsrc)]
                                                     , NumLit "1"
                                                     , [TRSimple [QName (name psrc)]]
                                                     )
                                       (ONE, _  ) -> ( NumLit "1"
                                                     , Iden [QName (name ptgt),QName (name ftgt)]
                                                     , [TRSimple [QName (name ptgt)]]
                                                     )
                                       _     -> if s == t
                                                then let a0 = QName (name fsrc)
                                                         a1 = QName (name fsrc++"1")
                                                     in
                                                     ( Iden [a0,QName (name fsrc)]
                                                     , Iden [a1,QName (name ftgt)]
                                                     , [TRSimple [QName (name psrc)] `as` a0
                                                       ,TRSimple [QName (name ptgt)] `as` a1]
                                                     )
                                                else ( Iden [QName (name psrc),QName (name fsrc)]
                                                     , Iden [QName (name ptgt),QName (name ftgt)]
                                                     , [TRSimple [QName (name psrc)]
                                                       ,TRSimple [QName (name ptgt)]]
                                                     )
                            in 
                               BSE { bseCmt = ""
                                   , bseSrc = src1
                                   , bseTrg = trg1
                                   , bseTbl = tbl1
                                   , bseWhr = Nothing
                                   }
    
    
    (EDcI c)             -> case c of
                              ONE ->   BSE { bseCmt = "I[ONE]"
                                           , bseSrc = NumLit "1"
                                           , bseTrg = NumLit "1"
                                           , bseTbl = []
                                           , bseWhr = Nothing
                                           }
                              PlainConcept{} -> 
                                 let cAtt = sqlAttConcept fSpec c
                                 in    BSE { bseCmt = "I["++name c++"]"
                                           , bseSrc = selectSelItem' (cAtt)
                                           , bseTrg = selectSelItem' (cAtt)
                                           , bseTbl = [sqlConceptTable fSpec c]
                                           , bseWhr = Just (notNull (Iden [cAtt]))
                                           }
    -- EEps behaves like I. The intersects are semantically relevant, because all semantic irrelevant EEps expressions have been filtered from es.
    (EEps c sgn)     -> case c of -- select the population of the most specific concept, which is the source.
                              ONE ->   BSE { bseCmt = "epsilon "++name c++" "++showSign sgn
                                           , bseSrc = NumLit "1"
                                           , bseTrg = NumLit "1"
                                           , bseTbl = []
                                           , bseWhr = Nothing
                                           }
                              PlainConcept{} -> 
                                 let cAtt = sqlAttConcept fSpec c
                                 in    BSE { bseCmt = "epsilon "++name c++" "++showSign sgn
                                           , bseSrc = selectSelItem' (cAtt)
                                           , bseTrg = selectSelItem' (cAtt)
                                           , bseTbl = [sqlConceptTable fSpec c]
                                           , bseWhr = Just (notNull (Iden [cAtt]))
                                           }
    (EDcD d)             -> selectExprRelationNew fSpec d

    (EBrk e)             -> selectExpr fSpec src trg e

    (ECpl e)
      -> case e of
           EDcV _        -> emptySet
           EDcI ONE      -> fatal 254 "EDcI ONE must not be seen at this place."
           EDcI c        ->            BSE { bseCmt = "case: ECpl (EDcI "++name c++")"
                                           , bseSrc = Iden [QName "concept0", concpt]
                                           , bseTrg = Iden [QName "concept1", concpt]
                                           , bseTbl = [sqlConceptTable fSpec c `as` QName "concept0"
                                                      ,sqlConceptTable fSpec c `as` QName "concept1"
                                                      ]
                                           , bseWhr = Just (BinOp (Iden [QName "concept0", concpt])
                                                                  [Name "<>"]
                                                                  (Iden [QName "concept1", concpt])
                                                           )
                                           }
                             where concpt = sqlAttConcept fSpec c
           _ | source e == ONE ->      BSE { bseCmt = "case: source e == ONE"++"ECpl ( \""++showADL e++"\" )"
                                           , bseSrc = NumLit "1"
                                           , bseTrg = Iden [sqlAttConcept fSpec (target e)]
                                           , bseTbl = [sqlConceptTable fSpec (target e)]
                                           , bseWhr = Just $ selectNotExists 
                                                               [selectExprInFROM fSpec src2 trg2 e `as` QName "cp"]
                                                               Nothing
                                           }
                                    where src2 = sqlExprSrc fSpec e
                                          trg2 = noCollide' [src2] (sqlExprTgt fSpec e)
           _ | target e == ONE ->      BSE { bseCmt = "case: target e == ONE"++"ECpl ( \""++showADL e++"\" )"
                                           , bseSrc = Iden [sqlAttConcept fSpec (source e)]
                                           , bseTrg = NumLit "1"
                                           , bseTbl = [sqlConceptTable fSpec (source e)]
                                           , bseWhr = Just $ selectNotExists 
                                                               [selectExprInFROM fSpec src2 trg2 e `as`QName "cp"]
                                                               Nothing
                                           }
                                  where src2 = sqlExprSrc fSpec e
                                        trg2 = noCollide' [src2] (sqlExprTgt fSpec e)
           _ | otherwise       -> sqlcomment ("case: ECpl e"++"ECpl ( \""++showADL e++"\" )") $
                                       BSE { bseCmt = "case: ECpl e"++"ECpl ( \""++showADL e++"\" )"
                                           , bseSrc = src'
                                           , bseTrg = trg'
                                           , bseTbl = [sqlConceptTable fSpec (source e) `as` Name "cfst"
                                                ,sqlConceptTable fSpec (target e) `as` Name "csnd"]
                                           , bseWhr = Just $ selectNotExists 
                                                               [selectExprInFROM fSpec src2 trg2 e `as` Name "cp"]
                                                               (Just . conjunctSQL $
                                                                  [ BinOp src'
                                                                          [Name "="]
                                                                          (Iden [Name "cp",src2])
                                                                  , BinOp trg'
                                                                          [Name "="]
                                                                          (Iden [Name "cp",trg2])
                                                                  ]
                                                               )
                                           }
                                    where src' = Iden [Name "cfst",sqlAttConcept fSpec (source e)]
                                          trg' = Iden [Name "csnd",sqlAttConcept fSpec (target e)]
                                          src2 = sqlExprSrc fSpec e
                                          trg2 = noCollide' [src2] (sqlExprTgt fSpec e)
    EKl0 _               -> fatal 249 "SQL cannot create closures EKl0 (`SELECT * FROM NotExistingKl0`)"
    EKl1 _               -> fatal 249 "SQL cannot create closures EKl1 (`SELECT * FROM NotExistingKl1`)"
    (EDif (EDcV _,x)) -> sqlcomment ("case: EDif V x"++"EDif V ( \""++showADL x++"\" ) \""++show (sign expr)++"\"")
                                    (selectExpr fSpec src trg (notCpl x))
-- The following definitions express code generation of the remaining cases in terms of the previously defined generators.
-- As a result of this way of working, code generated for =, |-, -, !, *, \, and / may not be efficient, but at least it is correct.
    EEqu (l,r)
      -> sqlcomment ("case: EEqu (l,r)"++showADL expr++" ("++show (sign expr)++")") $
         selectExpr fSpec src trg ((ECpl l .\/. r) ./\. (ECpl r .\/. l))
    EImp (l,r)
      -> sqlcomment ("case: EImp (l,r)"++showADL expr++" ("++show (sign expr)++")") $
         selectExpr fSpec src trg (ECpl l .\/. r)
    EDif (l,r)
      -> sqlcomment ("case: EDif (l,r)"++showADL expr++" ("++show (sign expr)++")") $
         selectExpr fSpec src trg (l ./\. ECpl r)
    ERrs (l,r) -- The right residual l\r is defined by: for all x,y:   x(l\r)y  <=>  for all z in X, z l x implies z r y.
{- In order to obtain an SQL-query, we make a Haskell derivation of the right residual:
             and [    (z,x)    `elem` contents l -> (z,y) `elem` contents r  | z<-contents (source l)]
   =
             and [    (z,x) `notElem` contents l || (z,y) `elem` contents r  | z<-contents (source l)]
   =
        not ( or [not((z,x) `notElem` contents l || (z,y) `elem` contents r) | z<-contents (source l)])
   =
        not ( or [    (z,x)  `elem` contents l && (z,y) `notElem` contents r | z<-contents (source l)])
   =
        null [ () | z<-contents (source l), (z,x)  `elem` contents l && (z,y) `notElem` contents r]
   =
        null [ () | z<-contents (source l), (z,x)  `elem` contents l, (z,y) `notElem` contents r]
   =
        null [ () | (z,x') <- contents l, x==x', (z,y) `notElem` contents r ]
   =
        null [ () | (z,x') <- contents l, x==x' && (z,y) `notElem` contents r ]

Based on this derivation:
  contents (l\r)
    = [(x,y) | x<-contents (target l), y<-contents (target r)
             , null [ () | (z,x') <- contents l, x==x', (z,y) `notElem` contents r ]
             ]
-}
      -> let rResiduClause
              | target l == ONE = fatal 332 ("ONE is unexpected as target of "++showADL l)
              | target r == ONE = fatal 333 ("ONE is unexpected as target of "++showADL r)
              | otherwise
                  = BSE { bseCmt = ""
                        , bseSrc = Iden [ srcAlias, mainSrc]
                        , bseTrg = Iden [ tgtAlias, mainTgt]
                        , bseTbl = [sqlConceptTable fSpec (target l) `as` srcAlias
                                  ,sqlConceptTable fSpec (target r) `as` tgtAlias]
                        , bseWhr = Just $ selectNotExists 
                                            [lCode `as` lhs]
                                            ( Just $ conjunctSQL
                                                [BinOp (Iden [srcAlias,mainSrc])
                                                       [Name "="]
                                                       (Iden [lhs,ltrg])
                                                ,selectNotExists 
                                                   [rCode `as` rhs]
                                                   ( Just $ conjunctSQL 
                                                      [BinOp (Iden [rhs,rsrc])
                                                             [Name "="]
                                                             (Iden [lhs,lsrc])
                                                      ,BinOp (Iden [rhs,rtrg])
                                                             [Name "="]
                                                             (Iden [tgtAlias,mainTgt])
                                                      ]
                                                   )
                                                ]
                                            )
                        }
             mainSrc = (sqlAttConcept fSpec.target) l  -- Note: this 'target' is not an error!!! It is part of the definition of right residu
             mainTgt = (sqlAttConcept fSpec.target) r
             relNames = foldrMapExpression uni (\decl->[QName (name decl)]) [] expr
             srcAlias = noCollide' relNames (QName "RResLeft")
             tgtAlias = noCollide' relNames (QName "RResRight")
             lhs  = QName "lhs"
             rhs  = QName "rhs"
             lsrc = sqlExprSrc fSpec l
             ltrg = sqlExprTgt fSpec l  -- shouldn't this be a noCollide? Apparently not. Introducing noCollide here has produced ticket #389
             rsrc = sqlExprSrc fSpec r
             rtrg = sqlExprTgt fSpec r  -- shouldn't this be a noCollide? (idem)
             lCode = selectExprInFROM fSpec lsrc ltrg l
             rCode = selectExprInFROM fSpec rsrc rtrg r
         in sqlcomment ("case: ERrs (l,r)"++showADL expr++" ("++show (sign expr)++")")
                         rResiduClause
    ELrs (l,r)
      -> sqlcomment ("case: ELrs (l,r)"++showADL expr++" ("++show (sign expr)++")") $
         selectExpr fSpec trg src (EFlp (flp r .\. flp l))
    EDia (l,r)
      -> sqlcomment ("case: EDia (l,r)"++showADL expr++" ("++show (sign expr)++")") $
         selectExpr fSpec trg src ((flp l .\. r) ./\. (l ./. flp r))
    ERad{}
      -> sqlcomment ("case: ERad (l,r)"++showADL expr++" ("++show (sign expr)++")") $
        selectExpr fSpec src trg (deMorganERad expr)
    EPrd (l,r)
     -> let v = EDcV (Sign (target l) (source r))
        in sqlcomment ("case: EPrd (l,r)"++showADL expr++" ("++show (sign expr)++")") $
           selectExpr fSpec src trg (foldr1 (.:.) [l,v,r])








-- | selectExprInFROM is meant for SELECT expressions inside a FROM clause.
--   It generates a simple table reference for primitive expressions (EDcD, EDcI, and EDcV) and a bracketed SQL expression in more complicated situations.
--   Note that selectExprInFROM makes sure that the attributes of the generated view correspond to the parameters src and trg.
--   Note that the resulting pairs do not contain any NULL values.

selectExprInFROM :: FSpec
                 -> Name      -- ^ source name (preferably quoted)
                 -> Name      -- ^ target name (preferably quoted)
                 -> Expression  -- ^ Whatever expression to generate an SQL query for
                 -> TableRef
selectExprInFROM fSpec src trg expr 
   | src == trg && (not.isIdent) expr = fatal 373 $ "selectExprInFrom must not be called with identical src and trg. ("++show src++") "++showADL expr
   | unquoted src = selectExprInFROM fSpec (toQName src) trg         expr
   | unquoted trg = selectExprInFROM fSpec src         (toQName trg) expr
   | otherwise    =
      case expr of
        EFlp e -> selectExprInFROM fSpec trg src e
        EBrk e -> selectExprInFROM fSpec src trg e
        EDcD d -> if sqlExprSrc fSpec expr === src && sqlExprTgt fSpec expr === trg
                  then ( if not mayContainNulls 
                         then TRSimple [declName]
                         else TRQueryExpr . toSQL $
                                       BSE { bseCmt = ""
                                           , bseSrc = selectSelItem' sAtt
                                           , bseTrg = selectSelItem' tAtt
                                           , bseTbl = [TRSimple [declName]]
                                           , bseWhr = Just $ conjunctSQL
                                               [notNull (Iden[src]), notNull (Iden[trg])]
                                           }
                       )
                  else TRQueryExpr . toSQL $   BSE { bseCmt = ""
                                           , bseSrc = selectSelItem' sAtt
                                           , bseTrg = selectSelItem' tAtt
                                           , bseTbl = [TRSimple [declName]]
                                           , bseWhr = if mayContainNulls
                                                      then (Just $ conjunctSQL
                                                              [notNull (Iden[sAtt]), notNull (Iden[tAtt])])
                                                      else Nothing
                                           }
                  where
                   sAtt = sqlExprSrc fSpec expr
                   tAtt = sqlExprTgt fSpec expr
                   (plug,_,_) = getDeclarationTableInfo fSpec d
                   (declName,mayContainNulls)
                      = (QName (name plug), case plug of 
                                              TblSQL{}  ->  True
                                              _         ->  False)
        EDcI ONE -> fatal 401 "ONE is unexpected at this place."
        EDcI c -> case (cpt, cptAlias) of
                    (cpt', (Iden [x])) -> if cpt'=== x
                                          then TRSimple [cpt']
                                          else sg
                    _                  -> sg
                 where  
                   sg = TRQueryExpr . toSQL $  BSE { bseCmt = " case: EDcI " ++ name c ++ " "
                                           , bseSrc = selectSelItem' (sqlAttConcept fSpec c)
                                           , bseTrg = Iden [sqlConcept fSpec c]
                                           , bseTbl = [sqlConceptTable fSpec c]
                                           , bseWhr = Nothing
                                           }
                   cptAlias = selectSelItem' (sqlAttConcept fSpec c)
                   cpt = sqlConcept fSpec c
        _      -> TRQueryExpr . toSQL $ selectExpr fSpec src trg expr
   where
     unquoted :: Name -> Bool
     unquoted (Name _ )   = True
     unquoted (QName _)   = False
     unquoted (UQName  _) = False --UQName = UNICODE quoted
     
(===) :: Name -> Name -> Bool
n === n' = stringOfName n == stringOfName n'

-- | does the same as noCollide, but ensures that all names used have `quotes` around them (for mySQL)
noCollide' :: [Name] -> Name -> Name
noCollide' nms nm = toQName (noCollide (map toUqName nms) (toUqName nm))
 where
   noCollide :: [Name] -- ^ forbidden names
             -> Name -- ^ preferred name
             -> Name -- ^ a unique name (does not occur in forbidden names)
   noCollide names nm' | nm'' `elem` map toUqName names = noCollide names (newNumber nm'')
                       | otherwise = nm'
    where
      nm''           = toUqName nm'
      newNumber :: Name -> Name
      newNumber nm1 = Name (reverse reverseNamePart++ changeNr (reverse reverseNumberpart))
        where
          ( reverseNumberpart, reverseNamePart) = span isDigit  . reverse . stringOfName $ nm1
      
      changeNr x     = int2string (string2int x+1)
      --  changeNr x = show (read x +1)
      string2int :: String -> Int
      string2int  = enc.reverse
       where enc "" = 0
             enc (c:cs) = digitToInt c + 10* enc cs
      int2string :: Int -> String
      int2string 0 = "0"
      int2string n = if n `div` 10 == 0 then [intToDigit (n `rem` 10) |n>0] else int2string (n `div` 10)++[intToDigit (n `rem` 10)]


-- | This function returns a (multy-lines) prettyprinted SQL qurey of a declaration. 
selectExprRelation :: FSpec
                   -> Declaration
                   -> String
selectExprRelation fSpec dcl
 = prettyQueryExpr . toSQL $ selectExprRelationNew fSpec dcl
     
selectExprRelationNew :: FSpec
         --          -> Name -- ^ Alias of source
         --          -> Name -- ^ Alias of target
                   -> Declaration
                   -> BinQueryExpr


selectExprRelationNew fSpec dcl =
  case dcl of
    Sgn{}  -> leafCode (getDeclarationTableInfo fSpec dcl)
    Isn{}  -> let (plug, c) = getConceptTableInfo fSpec (detyp dcl)
              in leafCode (plug, c, c)
    Vs sgn
     | source sgn == ONE -> fatal 468 "ONE is not expected at this place"
     | target sgn == ONE -> fatal 469 "ONE is not expected at this place"
     | otherwise
           -> let src,trg :: ValueExpr
                  src=Iden [Name "vfst", sqlAttConcept fSpec (source sgn)]
                  trg=Iden [Name "vsnd", sqlAttConcept fSpec (target sgn)]
              in BSE { bseCmt = ""
                     , bseSrc = src
                     , bseTrg = trg
                     , bseTbl = [sqlConceptTable fSpec (source sgn) `as` Name "vfst"
                                ,sqlConceptTable fSpec (target sgn) `as` Name "vsnd"]
                     , bseWhr = Just (conjunctSQL (map notNull [src,trg]))
                     }
   where
     leafCode :: (PlugSQL,SqlField,SqlField) -> BinQueryExpr
     leafCode (plug,s,t) = BSE { bseCmt = ""
                               , bseSrc = Iden [QName (name s)]
                               , bseTrg = Iden [QName (name t)]
                               , bseTbl = [TRSimple [QName (name plug)]]
                               , bseWhr = Just . conjunctSQL . map notNull $
                                            [Iden [QName (name c)] | c<-nub [s,t]]
                               }


selectExists, selectNotExists
     :: [TableRef]      -- ^ tables
     -> Maybe ValueExpr -- ^ the (optional) WHERE clause
     -> ValueExpr
selectNotExists tbls whr = PrefixOp [Name "NOT"] $ selectExists tbls whr
selectExists tbls whr = 
  SubQueryExpr SqExists
     Select { qeSetQuantifier = SQDefault
            , qeSelectList    = [(Star,Nothing)]
            , qeFrom          = tbls
            , qeWhere         = whr
            , qeGroupBy       = []
            , qeHaving        = Nothing
            , qeOrderBy       = []
            , qeOffset        = Nothing
            , qeFetchFirst    = Nothing
            }

-- | a (local) data structure to hold SQL info for binary expressions
data BinQueryExpr = BSE  { bseCmt :: String          -- ^ Comment for the binary SQL SELECT statement
                         , bseSrc :: ValueExpr       -- ^ source field and table
                         , bseTrg :: ValueExpr       -- ^ target field and table
                         , bseTbl :: [TableRef]      -- ^ tables
                         , bseWhr :: Maybe ValueExpr -- ^ the (optional) WHERE clause
                         }
                  | BCQE { bcqeCmt  :: String          -- ^ Comment for the binary CombineQueryExpr statement (Union, Intersect)
                         , bcqeOper :: CombineOp      -- ^ The combine operator 
                         , bcqe0    :: BinQueryExpr    -- ^ Left  expression
                         , bcqe1    :: BinQueryExpr    -- ^ Right expression
                         }
                        
toSQL :: BinQueryExpr -> QueryExpr
toSQL bqe 
 = case bqe of
    BSE{} -> Select { qeSetQuantifier = Distinct
                    , qeSelectList    = [ (bseSrc bqe, Just sourceAlias)
                                        , (bseTrg bqe, Just targetAlias)]
                    , qeFrom          = bseTbl bqe
                    , qeWhere         = bseWhr bqe
                    , qeGroupBy       = []
                    , qeHaving        = Nothing
                    , qeOrderBy       = []
                    , qeOffset        = Nothing
                    , qeFetchFirst    = Nothing
                    }
    BCQE{} -> CombineQueryExpr 
                    { qe0 = toSQL (bcqe0 bqe)
                    , qeCombOp = bcqeOper bqe
                    , qeSetQuantifier = SQDefault
                    , qeCorresponding = Respectively  -- ??? What does this mean?
                    , qe1 = toSQL (bcqe1 bqe)
                    }
selectSelItem' :: Name -> ValueExpr
selectSelItem' att = Iden [att] 

--selectSelItem :: (Name, Name) -> (ValueExpr ,Maybe Name)
--selectSelItem (att,alias)
--  | att === alias           = (Iden [toQName att], Nothing)
--  | stringOfName att == "1" = fatal 778 "ONE should have no named string" -- otherwise use: (NumLit "1", Just alias)
--  | otherwise               = (Iden [toQName att], Just alias)


-- | sqlExprSrc gives the quoted SQL-string that serves as the attribute name in SQL.
--   Quotes are added to prevent collision with SQL reserved words (e.g. ORDER).
--   We want it to show the type, which is useful for readability. (Otherwise, just "SRC" and "TGT" would suffice)
sqlExprSrc :: FSpec -> Expression -> Name
--sqlExprSrc fSpec expr = sourceAlias
sqlExprSrc fSpec (EDcV (Sign a _))   = sqlAttConcept fSpec a
sqlExprSrc fSpec (EDcI c)            = sqlAttConcept fSpec c
sqlExprSrc fSpec (EEps i _)          = sqlAttConcept fSpec i
sqlExprSrc fSpec (EFlp e)            = sqlExprTgt fSpec e
sqlExprSrc fSpec (EDcD d)            = let (_,s,_) = getDeclarationTableInfo fSpec d
                                       in QName (name s)
sqlExprSrc _     expr                = QName (name (source expr))


-- | sqlExprTgt gives the quoted SQL-string that serves as the attribute name in SQL.
sqlExprTgt :: FSpec -> Expression -> Name
--sqlExprTgt fSpec expr = targetAlias
sqlExprTgt fSpec (EDcV (Sign _ b))   = sqlAttConcept fSpec b
sqlExprTgt fSpec (EDcI c)            = sqlAttConcept fSpec c
sqlExprTgt fSpec (EEps i _)          = sqlAttConcept fSpec i
sqlExprTgt fSpec (EFlp e)            = sqlExprSrc fSpec e
sqlExprTgt fSpec (EDcD d)            = let (_,_,t) = getDeclarationTableInfo fSpec d
                                       in QName (name t)
sqlExprTgt _     expr                = QName (name (target expr))

-- sqlConcept gives the name of the plug that contains all atoms of A_Concept c.
-- Quotes are added just in case an SQL reserved word (e.g. "ORDER", "SELECT", etc.) is used as a concept name.
sqlConceptTable :: FSpec -> A_Concept -> TableRef
sqlConceptTable fSpec a = TRSimple [sqlConcept fSpec a]
sqlConcept :: FSpec -> A_Concept -> Name
sqlConcept fSpec = QName . name . sqlConceptPlug fSpec
-- sqlConcept yields the plug that contains all atoms of A_Concept c. Since there may be more of them, the first one is returned.
sqlConceptPlug :: FSpec -> A_Concept -> PlugSQL
sqlConceptPlug fSpec c | c==ONE = fatal 583 "A_Concept ONE may not be represented in SQL."
                       | otherwise
             = if null ps then fatal 585 $ "A_Concept \""++show c++"\" does not occur in fSpec." else
               head ps
               where ps = [plug |InternalPlug plug<-plugInfos fSpec
                                , not (null (case plug of ScalarSQL{} -> [c |c==cLkp plug]; _ -> [c' |(c',_)<-cLkpTbl plug, c'==c]))]

sqlAttConcept :: FSpec -> A_Concept -> Name
sqlAttConcept fSpec c | c==ONE = QName "ONE"
                      | otherwise
             = if null cs then fatal 594 $ "A_Concept \""++show c++"\" does not occur in its plug in fSpec \""++name fSpec++"\"" else
               QName (head cs)
               where cs = [name f |f<-plugFields (sqlConceptPlug fSpec c), c'<-concs f,c==c']


toUqName :: Name -> Name
toUqName = Name . stringOfName

toQName :: Name -> Name
toQName = QName . stringOfName

stringOfName :: Name -> String
stringOfName (Name s)   =  s
stringOfName (QName s)  =  s
stringOfName (UQName s) =  s

sqlAtomQuote :: String -> ValueExpr
sqlAtomQuote s = StringLit s

-- | for the time untill comment is supported, we use a dummy function 
sqlcomment :: String -> a -> a 
sqlcomment _ a = a 


conjunctSQL :: [ValueExpr] -> ValueExpr
conjunctSQL [] = fatal 57 "nothing to `AND`."
conjunctSQL [ve] = ve
conjunctSQL (ve:ves) = BinOp ve [Name "AND"] (conjunctSQL ves)

as :: TableRef -> Name -> TableRef
as ve a = -- TRAlias ve (Alias a Nothing)
  case ve of 
    TRSimple [n] -> if n === a then withoutAlias else withAlias
    _            -> withAlias
 where
   withoutAlias = ve
   withAlias = TRAlias ve (Alias a Nothing)
    
notNull :: ValueExpr -> ValueExpr
notNull ve = PostfixOp [Name "IS NOT NULL"] ve                         

emptySet :: BinQueryExpr
emptySet = BSE { bseCmt = "this will quaranteed return 0 rows:"
               -- select 1 as src, 1 as trg from (select 1) dummy where false
               , bseSrc = Iden [a]
               , bseTrg = Iden [a]
               , bseTbl = [TRQueryExpr  Select { qeSetQuantifier = SQDefault
                                               , qeSelectList = [(NumLit "1", Just a)]
                                               , qeFrom = []
                                               , qeWhere = Nothing
                                               , qeGroupBy = []
                                               , qeHaving = Nothing
                                               , qeOrderBy = []
                                               , qeOffset = Nothing
                                               , qeFetchFirst = Nothing
                                               } `as` Name "dummy"]
               , bseWhr = Just (BinOp (Iden [a]) [Name "<>"] (NumLit "1"))
               }
            where a = Name "a"


