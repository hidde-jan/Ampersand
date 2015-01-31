{-# LANGUAGE CPP #-}
module Database.Design.Ampersand.Prototype.ObjBinGen  (phpObjInterfaces) where

import Database.Design.Ampersand.Prototype.Installer           (installerDBstruct,installerDefPop)
import Database.Design.Ampersand.Prototype.ProtoUtil
import Database.Design.Ampersand.Prototype.Apps
import Database.Design.Ampersand.Prototype.Generate            (generateAll)
import Control.Monad
import System.FilePath
import System.Directory
import qualified Data.ByteString.Char8 as BS
import Database.Design.Ampersand.Prototype.CoreImporter
import Prelude hiding (writeFile,readFile,getContents)
import Database.Design.Ampersand.Prototype.StaticFiles_Generated

#ifdef MIN_VERSION_unix
import System.Posix.Files (setFileTimes) -- If unix is not available, we are on windows and cannot set file timestamps 

import Data.Time.Format -- not unix specific, but only needed if we set file timestamps
import System.Locale    -- 
#endif

phpObjInterfaces :: FSpec -> IO()
phpObjInterfaces fSpec =
 do { writeStaticFiles (getOpts fSpec)
    ; verboseLn (getOpts fSpec) "---------------------------"
    ; verboseLn (getOpts fSpec) "Generating php Object files with Ampersand"
    ; verboseLn (getOpts fSpec) "---------------------------"
    ; writePrototypeFile fSpec "InstallerDBstruct.php"     (installerDBstruct fSpec)
--    ; writePrototypeFile fSpec "InstallerTriggers.php"     (installerTriggers fSpec)
    ; writePrototypeFile fSpec "InstallerDefPop.php"       (installerDefPop fSpec)

    ; let dbSettingsFilePath = getGenericsDir fSpec </> "dbSettings.php"
    ; dbSettingsExists <- doesFileExist dbSettingsFilePath
    -- we generate a dbSettings.php only if it does not exist already.
    ; if dbSettingsExists
      then verboseLn (getOpts fSpec) "  Using existing dbSettings.php."
      else do { verboseLn (getOpts fSpec) "  Writing dbSettings.php."
              ; writePrototypeFile fSpec dbSettingsFilePath dbsettings
              }

    ; generateAll fSpec
    ; when (genAtlas (getOpts fSpec)) $ doGenAtlas fSpec
    ; verboseLn (getOpts fSpec) "\n"
    }
   where
    dbsettings = unlines
       [ "<?php"
       , ""
       , "global $DB_host,$DB_user,$DB_pass;"
       , "$DB_host='"++addSlashes (sqlHost (getOpts fSpec))++"';"
       , "$DB_user='"++addSlashes (sqlLogin (getOpts fSpec))++"';"
       , "$DB_pass='"++addSlashes (sqlPwd (getOpts fSpec))++"';"
       , ""
       , "$DB_link=mysqli_connect($DB_host, $DB_user, $DB_pass)"
       , "      or exit(\"Error connecting to the database: username / password are probably incorrect.\");"
       , ""
       , "?>"
       ]

doGenAtlas :: FSpec -> IO()
doGenAtlas fSpec =
 do { verboseLn (getOpts fSpec) "Installing the Atlas application:"
    ; verboseLn (getOpts fSpec) ("Importing "++show (importfile (getOpts fSpec))++" into namespace "++ show (namespace (getOpts fSpec)) ++" of the Atlas ...")
    ; verboseLn (getOpts fSpec) ("The atlas application should have been installed in " ++ show (dirPrototype (getOpts fSpec)) ++ ".")
    ; fillAtlas fSpec
    }

writeStaticFiles :: Options -> IO()
writeStaticFiles opts =
  if genStaticFiles opts
  then
 do {
#ifdef MIN_VERSION_unix
      verboseLn opts "Updating static files"
#else
      verboseLn opts "Writing static files"
#endif
    ; sequence_ [ writeWhenMissingOrOutdated opts sf (writeStaticFile opts sf) 
                | sf@SF{isNewFrontend=isNew} <- allStaticFiles, isNew == newFrontend opts
                ]
    }
  else
      verboseLn opts "Skipping static files (because of command line argument)"

writeWhenMissingOrOutdated :: Options -> StaticFile -> IO () -> IO ()
writeWhenMissingOrOutdated opts staticFile writeFileAction =
#ifdef MIN_VERSION_unix
-- On Mac/Linux we set the modification time for generated static files to the modification time of the compiled versions
-- in StaticFiles_Generated.hs. This allows us to only replace those static files that are outdated (or missing.) 
 do { exists <- doesFileExist $ absFilePath opts staticFile
    --; verboseLn opts $ "  Processing static file "++ filePath staticFile
    ; if exists then
       do { oldTimeStampUTC <- getModificationTime $ absFilePath opts staticFile
          ; let oldTimeStamp = read $ formatTime defaultTimeLocale "%s" oldTimeStampUTC -- convert to epoch seconds
          ; if oldTimeStamp < timeStamp staticFile then
              do { verboseLn opts $ "  Replacing static file "++ filePath staticFile ++" with current version."
                 ; writeFileAction
                 }
            else
              return () -- skip is not really worth logging
          }
      else
       do { verboseLn opts $ "  Writing static file "++ filePath staticFile
          ; writeFileAction
          }
    }
#else
-- On windows we cannot set the file modification time without requiring a cygwin or mingw build environment,
-- so we simply replace all static files on each generation.
 do { verboseLn opts $ "  Writing static file "++ filePath staticFile
    ; writeFileAction
    }
#endif

writeStaticFile :: Options -> StaticFile -> IO()
writeStaticFile opts sf =
  do { createDirectoryIfMissing True (takeDirectory (absFilePath opts sf))
     ; write (absFilePath opts sf) (contentString sf)
#ifdef MIN_VERSION_unix
     ; let t = (fromIntegral $ timeStamp sf)
     ; setFileTimes (absFilePath opts sf) t t
#endif
     }
 where write a b = BS.writeFile a (BS.pack b)

absFilePath :: Options -> StaticFile -> FilePath
absFilePath opts sf = combine (dirPrototype opts) (filePath sf)