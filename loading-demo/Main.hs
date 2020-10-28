{-# LANGUAGE
  QuasiQuotes, TemplateHaskell,
  StandaloneDeriving, DeriveGeneric, DeriveDataTypeable, DeriveLift,
  FlexibleInstances, MultiParamTypeClasses,
  DataKinds, TypeFamilies
  #-}
module Main where

import Data.Text (Text)
import Data.Word (Word16, Word32, Word64)
import Domain


main =
  return ()

declare
  (Just (True, False))
  (mconcat [
    deriveBase,
    deriveHashable,
    deriveIsLabel,
    deriveHasField
    ])
  =<< loadSchema "samples/1.yaml"
