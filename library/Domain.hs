module Domain
(
  -- * Declaration
  declare,
  -- * Schema
  Schema,
  schema,
  loadSchema,
  -- * Deriver
  Deriver.Deriver,
  deriveAll,
  -- ** Base
  deriveBase,
  -- *** Specific
  deriveEnum,
  deriveBounded,
  deriveShow,
  deriveEq,
  deriveOrd,
  deriveGeneric,
  deriveData,
  deriveTypeable,
  -- ** Common
  deriveHashable,
  deriveLift,
  -- ** HasField
  deriveHasField,
  -- ** IsLabel
  -- |
  -- Custom instances of 'IsLabel'.
  deriveIsLabel,
  -- *** Specific
  deriveAccessorIsLabel,
  deriveConstructorIsLabel,
  deriveMapperIsLabel,
)
where

import Domain.Prelude hiding (liftEither, readFile, lift)
import Language.Haskell.TH.Syntax
import Language.Haskell.TH.Quote
import qualified Data.ByteString as ByteString
import qualified Data.Text.Encoding as Text
import qualified Domain.Resolvers.TypeCentricDoc as TypeCentricResolver
import qualified Domain.TH.TypeDec as TypeDec
import qualified Domain.TH.InstanceDecs as InstanceDecs
import qualified Domain.YamlUnscrambler.TypeCentricDoc as TypeCentricYaml
import qualified DomainCore.Deriver as Deriver
import qualified DomainCore.Model as Model
import qualified YamlUnscrambler


{-|
Declare datatypes and typeclass instances
from a schema definition according to the provided settings.

Use this function in combination with the 'schema' quasi-quoter or
the 'loadSchema' function.
__For examples__ refer to their documentation.

Call it on the top-level (where you declare your module members).
-}
declare ::
  {-|
  Field naming.
  When nothing, no fields will be generated.
  Otherwise the first wrapped boolean specifies,
  whether to prefix the names with underscore,
  and the second - whether to prefix with the type name.
  Please notice that when you choose not to prefix with the type name
  you need to have the @DuplicateRecords@ extension enabled.
  -}
  Maybe (Bool, Bool) ->
  {-|
  Which instances to derive and how.
  -}
  Deriver.Deriver ->
  {-|
  Schema definition.
  -}
  Schema ->
  {-|
  Template Haskell action splicing the generated code on declaration level.
  -}
  Q [Dec]
declare fieldNaming (Deriver.Deriver derive) (Schema schema) =
  do
    instanceDecs <- fmap (nub . concat) (traverse derive schema)
    return (fmap (TypeDec.typeDec fieldNaming) schema <> instanceDecs)


-- * Schema
-------------------------

{-|
Parsed and validated schema.

You can only produce it using the 'schema' quasi-quoter or
the 'loadSchema' function
and generate the code from it using 'declare'.
-}
newtype Schema =
  Schema [Model.TypeDec]
  deriving (Lift)

{-|
Quasi-quoter, which parses a YAML schema into a 'Schema' expression.

Use 'declare' to generate the code from it.

=== __Example__

@
{\-# LANGUAGE
  QuasiQuotes, TemplateHaskell,
  StandaloneDeriving, DeriveGeneric, DeriveDataTypeable, DeriveLift,
  FlexibleInstances, MultiParamTypeClasses,
  DataKinds, TypeFamilies
  #-\}
module Model where

import Data.Text (Text)
import Data.Word (Word16, Word32, Word64)
import Domain

'declare'
  (Just (False, True))
  'deriveAll'
  ['schema'|

    Host:
      sum:
        ip: Ip
        name: Text

    Ip:
      sum:
        v4: Word32
        v6: Word128

    Word128:
      product:
        part1: Word64
        part2: Word64

    |]
@

-}
schema :: QuasiQuoter
schema =
  QuasiQuoter exp pat type_ dec
  where
    unsupported =
      const (fail "Quotation in this context is not supported")
    exp =
      lift <=< parseString
    pat =
      unsupported
    type_ =
      unsupported
    dec =
      unsupported

{-|
Load and parse a YAML file into a schema definition.

Use 'declare' to generate the code from it.

=== __Example__

@
{\-# LANGUAGE
  QuasiQuotes, TemplateHaskell,
  StandaloneDeriving, DeriveGeneric, DeriveDataTypeable, DeriveLift,
  FlexibleInstances, MultiParamTypeClasses,
  DataKinds, TypeFamilies
  #-\}
module Model where

import Data.Text (Text)
import Data.Word (Word16, Word32, Word64)
import Domain

'declare'
  (Just (True, False))
  (mconcat [
    'deriveBase',
    'deriveIsLabel',
    'deriveHashable',
    'deriveHasField'
    ])
  =<< 'loadSchema' "domain.yaml"
@
-}
loadSchema ::
  {-|
  Path to the schema file relative to the root of the project.
  -}
  FilePath ->
  {-|
  Template Haskell action producing a valid schema.
  -}
  Q Schema
loadSchema path =
  readFile path >>= parseByteString


-- * Helpers
-------------------------

readFile :: FilePath -> Q ByteString
readFile path =
  do
    addDependentFile path
    readRes <- liftIO (tryIOError (ByteString.readFile path))
    liftEither (first showAsText readRes)

parseString :: String -> Q Schema
parseString =
  parseText . fromString

parseText :: Text -> Q Schema
parseText =
  parseByteString . Text.encodeUtf8

parseByteString :: ByteString -> Q Schema
parseByteString input =
  liftEither $ do
    doc <- YamlUnscrambler.parseByteString TypeCentricYaml.doc input
    decs <- TypeCentricResolver.eliminateDoc doc
    return (Schema decs)

liftEither :: Either Text a -> Q a
liftEither =
  \ case
    Left err -> fail (toList err)
    Right a -> return a 


-- * Deriver
-------------------------

{-|
Combination of all derivers exported by this module.
-}
deriveAll =
  mconcat [
    deriveBase,
    deriveIsLabel,
    deriveHashable,
    deriveLift,
    deriveHasField
    ]


-- * Base
-------------------------

{-|
Combination of all derivers for classes from the \"base\" package.
-}
deriveBase =
  mconcat [
    deriveEnum,
    deriveBounded,
    deriveShow,
    deriveEq,
    deriveOrd,
    deriveGeneric,
    deriveData,
    deriveTypeable
    ]

{-|
Derives 'Enum' for types from the \"enum\" section of spec.

Requires to have the @StandaloneDeriving@ compiler extension enabled.
-}
deriveEnum =
  Deriver.effectless InstanceDecs.enum

{-|
Derives 'Bounded' for types from the \"enum\" section of spec.

Requires to have the @StandaloneDeriving@ compiler extension enabled.
-}
deriveBounded =
  Deriver.effectless InstanceDecs.bounded

{-|
Derives 'Show'.

Requires to have the @StandaloneDeriving@ compiler extension enabled.
-}
deriveShow =
  Deriver.effectless InstanceDecs.show

{-|
Derives 'Eq'.

Requires to have the @StandaloneDeriving@ compiler extension enabled.
-}
deriveEq =
  Deriver.effectless InstanceDecs.eq

{-|
Derives 'Ord'.

Requires to have the @StandaloneDeriving@ compiler extension enabled.
-}
deriveOrd =
  Deriver.effectless InstanceDecs.ord

{-|
Derives 'Generic'.

Requires to have the @StandaloneDeriving@ and @DeriveGeneric@ compiler extensions enabled.
-}
deriveGeneric =
  Deriver.effectless InstanceDecs.generic

{-|
Derives 'Data'.

Requires to have the @StandaloneDeriving@ and @DeriveDataTypeable@ compiler extensions enabled.
-}
deriveData =
  Deriver.effectless InstanceDecs.data_

{-|
Derives 'Typeable'.

Requires to have the @StandaloneDeriving@ and @DeriveDataTypeable@ compiler extensions enabled.
-}
deriveTypeable =
  Deriver.effectless InstanceDecs.typeable

{-|
Generates 'Generic'-based instances of 'Hashable'.
-}
deriveHashable =
  Deriver.effectless InstanceDecs.hashable

{-|
Derives 'Lift'.

Requires to have the @StandaloneDeriving@ and @DeriveLift@ compiler extensions enabled.
-}
deriveLift =
  Deriver.effectless InstanceDecs.lift


-- * HasField
-------------------------

{-|
Derives 'HasField' with unprefixed field names.

For each field of product generates instances mapping to their values.

For each constructor of a sum maps to a 'Maybe' tuple of members of that constructor.

For each variant of an enum maps to 'Bool' signaling whether the value equals to it.

For wrapper maps the symbol \"value\" to the contents of the wrapper.

/Please notice that if you choose to generate unprefixed record field accessors, it will conflict with this deriver, since it\'s gonna generate duplicate instances./
-}
deriveHasField =
  Deriver.effectless InstanceDecs.hasField


-- * IsLabel
-------------------------

{-|
Generates instances of 'IsLabel' for wrappers, enums and sums,
providing mappings from labels to constructors.

=== __Example__

For the following spec:

>sums:
>  ApiError:
>    unauthorized:
>    rejected: Maybe Text

It'll generate the following instances:

>instance IsLabel "unauthorized" ApiError where
>  fromLabel = UnauthorizedApiError
>
>instance IsLabel "rejected" (Maybe Text -> ApiError) where
>  fromLabel = RejectedApiError

Allowing you to construct the value by simply addressing the label:

>unauthorizedApiError :: ApiError
>unauthorizedApiError = #unauthorized
>
>rejectedApiError :: Maybe Text -> ApiError
>rejectedApiError reason = #rejected reason

To make use of that ensure to have the @OverloadedLabels@ compiler extension enabled.
-}
deriveConstructorIsLabel =
  Deriver.effectless InstanceDecs.constructorIsLabel

{-|
Generates instances of 'IsLabel' for wrappers, enums, sums and products,
providing mappings from labels to component accessors.

=== __Product example__

The following spec:

>products:
>  Config:
>    host: Text
>    port: Int

Will generate the following instances:

>instance a ~ Text => IsLabel "host" (Config -> a) where
>  fromLabel = \ (Config a _) -> a
>instance a ~ Word16 => IsLabel "port" (Config -> a) where
>  fromLabel = \ (Config _ b) -> b

Which you can use to access individual fields as follows:

>getConfigHost :: Config -> Text
>getConfigHost = #host

To make use of that ensure to have the @OverloadedLabels@ compiler extension enabled.
-}
deriveAccessorIsLabel =
  Deriver.effectless InstanceDecs.accessorIsLabel

deriveMapperIsLabel =
  Deriver.effectless InstanceDecs.mapperIsLabel

{-|
Combination of 'deriveConstructorIsLabel', 'deriveMapperIsLabel' and 'deriveAccessorIsLabel'.
-}
deriveIsLabel =
  deriveConstructorIsLabel <>
  deriveMapperIsLabel <>
  deriveAccessorIsLabel
