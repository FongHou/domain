module Main
where

import Prelude
import Domain
import qualified Domain.Deriver as Deriver


main =
  return ()

declare Deriver.base [spec|
  
  wrappers:
    ApiKey: Text
    ApiSecret: Text
    ContractId: UUID
    Price: Scientific
    SpotPrice: Scientific
    SecondsSinceEpoch: Int64
    ContractSymbol: Text
    OrderId: UUID
    Size:

  sums:
    ApiError:
      invalidData:
      unauthorized:
      rejected: Maybe Text
      apiKeyNotFound:
      signatureMismatch:

  products:
    Pagination:
      currentPage: Int
      pageSize: Int
      totalCount: Int
    Order:
      id: OrderId
      type: OrderType
      side: Side
      status: OrderStatus
      limitPrice: Price
      stopPrice: Price
      size: Size
      filledPrice: Price
      cancelledSize: Size
      timeInForce: TimeInForce
      symbol: ContractSymbol
    Contract:
      symbol: ContractSymbol
      description: Text
      type: ContractType
      tickSize: Scientific
      impactSize: Scientific
      status: ContractStatus
      initialMargin: Scientific
      maintenanceMargin: Scientific
      positionSizeLimit: Scientific
      settlementTime: UTCTime
      underlyingAsset: Asset
    Asset:

  enums:
    ContractStatus:
      - operational
      - disrupted
      - disruptedPostOnly
      - expired
    ContractType:
      - future
      - perpetual
    OrderType:
      - limit
      - market
    OrderStatus:
      - open
      - filled
      - inactive
      - rejected
      - cancelled
    Side:
      - buy
      - sell
    TimeInForce:
      - goodTillCancelled
      - fillOrKill
      - immediateOrCancel

  |]