module Domain.Deriver.TH
where

import Domain.Prelude
import Language.Haskell.TH
import qualified Domain.Model as Mo
import qualified Data.Text as Text
import qualified Domain.TH as TH
import qualified TemplateHaskell.Compat.V0208 as Compat


enumInstanceDecs =
  enumTypeDecDerivingInstanceDecs ''Enum

boundedInstanceDecs =
  enumTypeDecDerivingInstanceDecs ''Bounded

showInstanceDecs =
  nonAliasTypeDecDerivingInstanceDecs ''Show

eqInstanceDecs =
  nonAliasTypeDecDerivingInstanceDecs ''Eq

ordInstanceDecs =
  nonAliasTypeDecDerivingInstanceDecs ''Ord

genericInstanceDecs =
  nonAliasTypeDecDerivingInstanceDecs ''Generic

dataInstanceDecs =
  nonAliasTypeDecDerivingInstanceDecs ''Data

typeableInstanceDecs =
  nonAliasTypeDecDerivingInstanceDecs ''Typeable

hashableInstanceDecs =
  nonAliasTypeDecEmptyInstanceDecs ''Hashable

liftInstanceDecs =
  nonAliasTypeDecDerivingInstanceDecs ''Lift


nonAliasTypeDecEmptyInstanceDecs className =
  \ case
    Mo.TypeDec a b ->
      case b of
        Mo.AliasTypeDef _ ->
          []
        _ ->
          [emptyInstanceDec className a]

nonAliasTypeDecDerivingInstanceDecs className =
  \ case
    Mo.TypeDec a b ->
      case b of
        Mo.AliasTypeDef _ ->
          []
        _ ->
          [derivingInstanceDec className a]

enumTypeDecDerivingInstanceDecs className =
  \ case
    Mo.TypeDec a b ->
      case b of
        Mo.EnumTypeDef c ->
          [derivingInstanceDec className a]
        _ ->
          []


derivingInstanceDec className typeNameText =
  StandaloneDerivD Nothing [] headType
  where
    headType =
      AppT (ConT className) (ConT (TH.textName typeNameText))

emptyInstanceDec className typeNameText =
  InstanceD Nothing [] headType []
  where
    headType =
      AppT (ConT className) (ConT (TH.textName typeNameText))


constructorIsLabelInstanceDecs =
  \ case
    Mo.TypeDec a b ->
      case b of
        Mo.AliasTypeDef _ -> []
        Mo.WrapperTypeDef c -> []
        Mo.EnumTypeDef c ->
          fmap (enumConstructorIsLabelInstanceDec a) c
        Mo.SumTypeDef c ->
          fmap (uncurry (sumConstructorIsLabelInstanceDec a)) c
        Mo.ProductTypeDef c -> []

wrapperConstructorIsLabelInstanceDec typeName type_ =
  InstanceD Nothing [] headType bodyDecs
  where
    headType =
      listAppT (ConT ''IsLabel) [labelType, repType]
      where
        labelType =
          LitT (StrTyLit "value")
        repType =
          listAppT ArrowT [payloadType, sumType]
          where
            payloadType =
              TH.typeType type_
            sumType =
              ConT (TH.textName typeName)
    bodyDecs =
      [fromLabelDec]
      where
        fromLabelDec =
          FunD 'fromLabel [Clause [] body []]
          where
            body =
              NormalB (ConE (TH.textName typeName))

enumConstructorIsLabelInstanceDec typeName label =
  InstanceD Nothing [] headType bodyDecs
  where
    headType =
      AppT (AppT (ConT ''IsLabel) (LitT (StrTyLit (toList label))))
        (ConT (TH.textName typeName))
    bodyDecs =
      [fromLabelDec]
      where
        fromLabelDec =
          FunD 'fromLabel [Clause [] body []]
          where
            body =
              NormalB (ConE (TH.sumConstructorName typeName label))

sumConstructorIsLabelInstanceDec :: Text -> Text -> [Mo.Type] -> Dec
sumConstructorIsLabelInstanceDec typeName label memberTypes =
  InstanceD Nothing [] headType bodyDecs
  where
    headType =
      listAppT (ConT ''IsLabel) [labelType, repType]
      where
        labelType =
          LitT (StrTyLit (toList label))
        repType =
          foldr (\ a b -> AppT (AppT ArrowT a) b) sumType $
          fmap TH.typeType memberTypes
          where
            sumType =
              ConT (TH.textName typeName)
    bodyDecs =
      [fromLabelDec]
      where
        fromLabelDec =
          FunD 'fromLabel [Clause [] body []]
          where
            body =
              NormalB (ConE (TH.sumConstructorName typeName label))

listAppT base args =
  foldl' AppT base args


accessorIsLabelInstanceDecs =
  \ case
    Mo.TypeDec a b ->
      case b of
        Mo.AliasTypeDef _ -> []
        Mo.WrapperTypeDef c ->
          [wrapperAccessorIsLabelInstanceDec a c]
        Mo.EnumTypeDef c ->
          fmap (enumAccessorIsLabelInstanceDec a) c
        Mo.ProductTypeDef c ->
          fmap (uncurry (productAccessorIsLabelInstanceDec a)) c
        Mo.SumTypeDef c ->
          fmap (uncurry (sumAccessorIsLabelInstanceDec a)) c

wrapperAccessorIsLabelInstanceDec typeName type_ =
  productAccessorIsLabelInstanceDec typeName "value" type_

enumAccessorIsLabelInstanceDec :: Text -> Text -> Dec
enumAccessorIsLabelInstanceDec typeName label =
  InstanceD Nothing [] headType [fromLabelDec]
  where
    conName =
      TH.sumConstructorName typeName label
    headType =
      listAppT (ConT ''IsLabel) [labelType, repType]
      where
        labelType =
          LitT (StrTyLit (toList label))
        repType =
          listAppT ArrowT [sumType, resultType]
          where
            sumType =
              ConT (TH.textName typeName)
            resultType =
              ConT ''Bool
    fromLabelDec =
      FunD 'fromLabel [Clause [] (NormalB exp) []]
      where
        exp =
          LamCaseE [positiveMatch, negativeMatch]
          where
            positiveMatch =
              Match pat (NormalB exp) []
              where
                pat =
                  ConP conName []
                exp =
                  ConE 'True
            negativeMatch =
              Match WildP (NormalB exp) []
              where
                exp =
                  ConE 'False

sumAccessorIsLabelInstanceDec :: Text -> Text -> [Mo.Type] -> Dec
sumAccessorIsLabelInstanceDec typeName label memberTypes =
  case null memberTypes of
    True ->
      enumAccessorIsLabelInstanceDec typeName label
    False ->
      InstanceD Nothing [] headType bodyDecs
      where
        conName =
          TH.sumConstructorName typeName label
        headType =
          listAppT (ConT ''IsLabel) [labelType, repType]
          where
            labelType =
              LitT (StrTyLit (toList label))
            repType =
              listAppT ArrowT [sumType, resultType]
              where
                resultType =
                  AppT (ConT ''Maybe) (tupleType memberTypes)
                sumType =
                  ConT (TH.textName typeName)
        bodyDecs =
          [fromLabelDec]
          where
            fromLabelDec =
              FunD 'fromLabel [Clause [] (NormalB exp) []]
              where
                exp =
                  LamCaseE [positiveMatch, negativeMatch]
                  where
                    memberTypesLength =
                      length memberTypes
                    varNames =
                      fmap (mkName . showString "_" . show)
                        (enumFromTo 1 memberTypesLength)
                    positiveMatch =
                      Match pat (NormalB exp) []
                      where
                        pat =
                          ConP conName varPats
                          where
                            varPats =
                              varNames & fmap VarP
                        exp =
                          AppE (ConE 'Just)
                            (Compat.tupE (fmap VarE varNames))
                    negativeMatch =
                      Match WildP (NormalB exp) []
                      where
                        exp =
                          ConE 'Nothing

tupleType a =
  foldl' AppT (TupleT (length a)) (fmap TH.typeType a)

productAccessorIsLabelInstanceDec typeName field type_ =
  InstanceD Nothing [] headType [fromLabelDec]
  where
    headType =
      listAppT (ConT ''IsLabel) [labelType, repType]
      where
        labelType =
          LitT (StrTyLit (toList field))
        repType =
          listAppT ArrowT [compositeType, resultType]
          where
            compositeType =
              ConT (TH.textName typeName)
            resultType =
              TH.typeType type_
    fromLabelDec =
      FunD 'fromLabel [Clause [] (NormalB exp) []]
      where
        exp =
          VarE (TH.recordFieldName typeName field)
