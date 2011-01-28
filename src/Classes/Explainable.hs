{-# OPTIONS_GHC -Wall #-}
module Classes.Explainable (explanationDeclarations) 
where
  import DatabaseDesign.Ampersand.ADL.Context                 (Context(..))
  import DatabaseDesign.Ampersand.ADL.Pattern                 (Pattern(..))
  import DatabaseDesign.Ampersand.ADL.MorphismAndDeclaration  (makeDeclaration,Identified(..))
  import Data.Explain
  import Options 
  import DatabaseDesign.Ampersand.ADL.Explanation
  import Classes.ViewPoint

-- For parser data structures (which are: ConceptDef, Declaration, Population, Rule, Gen, KeyDef, ObjectDef, Pattern and Context)
-- the function <explanations :: a -> [Explanation]> gives all explanations that are declared directly in <a>, but not in possible components of <a>.
-- So if <a> is a context, it gives the explanations declared in <a>, but not those declared in patterns in <a>

  class ViewPoint a => UserExplainable a where
    pExplains :: a -> PExplanations
    explanationDeclarations :: Options -> a -> Explanations -- all explanations declared in <a>. An explanation should answer the question "Why does <a> exist?"
    explanationDeclarations flags ue
     = [Expl (toExplObj pExplObj) l ref (string2ExplainContent flags expla) | PExpl pExplObj l ref expla        <- pExplains ue]
         where
           toExplObj :: PExplObj -> ExplObj
           toExplObj pe = case pe of 
             PExplConceptDef str  -> ExplConceptDef (getByName str (conceptDefs ue))
             PExplDeclaration rel -> ExplDeclaration (makeDeclaration rel)
             PExplRule str        -> ExplRule (getByName str (rules ue++signals ue))
             PExplKeyDef str      -> ExplKeyDef (getByName str (keyDefs ue))
             PExplObjectDef str   -> ExplObjectDef (getByName str (objDefs ue))
             PExplPattern str     -> ExplPattern str
             PExplContext str     -> ExplContext str
           getByName :: Identified a => String -> [a] -> a 
           getByName str cds = 
              case (filter hasRightName cds) of
                []  -> error ("!Fatal (module Explainable 35): No definition for '"++str++"'.")
                [c] -> c
                _   -> error ("!Fatal (module Explainable 37): Multiple definitions for '"++str++"'.")
             where
               hasRightName cd = name cd == str   

  instance UserExplainable Context where
    pExplains context = ctxps context
 
  instance UserExplainable Pattern where
    pExplains pat = ptxps pat
  
  
  
