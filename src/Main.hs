 {-# LANGUAGE ScopedTypeVariables#-}
module Main where


import Options               (getOptions,Options(..),usageInfo')
import Version               (versionbanner)
import Parser                (parseADL)
import Data.ADL              (Context)
import Data.Fspec            (Fspc)
import ADL2Fspec             (makeFspec)
import Generators            

import MainOUDEMEUK (mainold)
main :: IO ()
--main = mainold
main = mainnew



mainnew :: IO ()
mainnew
 = do flags <- getOptions   
      if showVersion flags
       then putStrLn versionbanner
       else if showHelp flags 
       then mapM_ putStrLn [(usageInfo' (progrName flags))]
       else do context <- phase1 flags 
               fSpec   <- phase2 flags context
               phase3 flags fSpec
       

phase1 :: Options -> IO(Context)
phase1 flags  
      = let fnFull = adlFileName flags in
        do verbose flags "Parsing... "
           adlText <- readFile fnFull
           context <- parseADL adlText flags fnFull 
           return context

phase2 :: Options -> Context -> IO(Fspc)
phase2 flags context = do verboseLn flags "Calculating..."
                          return (makeFspec context)
                          
phase3 :: Options -> Fspc -> IO()
phase3 flags fSpec = 
    sequence_ 
       ([ verboseLn flags "Generating..."]++
      --[ anal context ("-p" `elem` switches) (lineStyle switches) | null switches || "-h" `elem` switches]++
      --[ makeXML_depreciated context| "-XML" `elem` switches]++
        [ showHaskell fSpec flags | haskell flags] ++ 
--        [ serviceGen fSpec (language flags) filename| "-services" `elem` switches]
      --[ diagnose context| "-diag" `elem` switches]++
      --[ functionalSpecLaTeX context (lineStyle switches) (lang switches) filename| "-fSpec" `elem` switches]++
      --[ cdModel context | "-CD" `elem` switches]++
      --[ phpObjServices context fSpec filename dbName ("./"++filename++"/") | "-phpcode" `elem` switches]++
      --[ phpServices context filename dbName True True | "-beeper" `elem` switches]++
      --[ phpServices context filename dbName ("-notrans" `elem` switches) False| "-checker" `elem` switches]++
      --[ deriveProofs context ("-m" `elem` switches)| "-proofs" `elem` switches]
 --               ++[ projectSpecText context (lang switches) | "-project" `elem` switches]
 --               ++[ csvcontent context | "-csv" `elem` switches]
 --               ++[ putStr (show slRes) | "-dump" `elem` switches ]
 --    ) 
        [ verbose flags "Done."]
       ) 
                               

