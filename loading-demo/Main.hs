module Main
where

import Prelude
import Domain
import qualified Domain.Deriver as Deriver


main =
  return ()

load False Deriver.isLabel "samples/1.yaml"
