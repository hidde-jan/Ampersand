{-# OPTIONS_GHC -Wall #-}
module DatabaseDesign.Ampersand.ADL1 
   ( module DatabaseDesign.Ampersand.Core.ParseTree
   , module DatabaseDesign.Ampersand.Core.AbstractSyntaxTree
   , module DatabaseDesign.Ampersand.ADL1.Expression
   , module DatabaseDesign.Ampersand.ADL1.ECArule
   , module DatabaseDesign.Ampersand.ADL1.Rule
   ) 
where
import DatabaseDesign.Ampersand.Core.ParseTree (
           PPurpose(..), PRef2Obj(..)
         , Paire, Pairs, mkPair , srcPaire, trgPaire
         , Label(..)
         , FilePos(..), Origin(..), Pos(..), Traced(..)
         , Prop(..)
         , P_Concept(..)
         , P_Sign(..)
         , P_Context(..)
         , Meta(..)
         , MetaObj(..)
         , P_Process(..), P_RoleRelation(..), RoleRule(..)
         , P_Pattern(..)
         , PairView(..), PairViewSegment(..)
         , SrcOrTgt(..)
         , P_Rule(..)
         , P_IdentDef(..), P_IdentSegment(..)
         , P_ViewDef, P_ViewSegment
         , P_Population(..)
         , P_ObjectDef
         , P_Interface(..)
         , P_SubInterface
         , Term(..)
         , TermPrim(..)
         , P_Gen(..)
         , P_Declaration(..)
         , ConceptDef(..)
         , gen_concs
         )
import DatabaseDesign.Ampersand.Core.AbstractSyntaxTree (
          A_Concept(..)
         ,Sign(..),showSign,GenR()
         , (<==>),meet,join
         ,A_Context(..),Process(..)
         ,Association(..)
         ,Expression(..)
         ,A_Gen(..)
         ,IdentityDef(..)
         ,IdentitySegment(..)
         ,ViewDef(..)
         ,ViewSegment(..)
         ,ObjectDef(..)
         ,SubInterface(..)
         ,Declaration(..),decusr
         ,Interface(..)
         ,Pattern(..)
         ,Rule(..)
         ,RuleType(..)
         ,RoleRelation(..)
         ,Population(..)
         ,Purpose(..), ExplObj(..)
         , (.==.), (.|-.), (./\.), (.\/.), (.-.), (./.), (.\.), (.<>.), (.:.), (.!.), (.*.)
         )
import DatabaseDesign.Ampersand.ADL1.Expression
         ( notCpl, isCpl, deMorganERad, deMorganECps, deMorganEUni, deMorganEIsc
         , exprIsc2list, exprUni2list, exprCps2list, exprRad2list, exprPrd2list
         , insParentheses)
import DatabaseDesign.Ampersand.ADL1.ECArule (
         isAll, isCHC, isBlk, isNop, isDo, eventsFrom)
import DatabaseDesign.Ampersand.ADL1.Rule (
          rulefromProp, ruleviolations
         ,consequent,antecedent,hasantecedent)