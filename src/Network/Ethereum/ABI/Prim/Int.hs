{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures             #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeOperators              #-}

-- |
-- Module      :  Network.Ethereum.Encoding.Prim.Int
-- Copyright   :  Alexander Krupenkin 2016-2018
-- License     :  BSD3
--
-- Maintainer  :  mail@akru.me
-- Stability   :  experimental
-- Portability :  noportable
--
-- Ethereum ABI intN and uintN types.
--

module Network.Ethereum.ABI.Prim.Int (
    IntN
  , UIntN
  , getWord256
  , putWord256
  ) where

import qualified Basement.Numerical.Number  as Basement (toInteger)
import           Basement.Types.Word256     (Word256 (Word256))
import qualified Basement.Types.Word256     as Basement (quot, rem)
import           Data.Bits                  (Bits (testBit))
import           Data.Hashable              (Hashable (hashWithSalt))
import           Data.Proxy                 (Proxy (..))
import           Data.Serialize             (Get, Putter, Serialize (get, put))
import           GHC.Generics               (Generic)
import           GHC.TypeLits

import           Network.Ethereum.ABI.Class (ABIGet (..), ABIPut (..),
                                             ABIType (..))

instance Real Word256 where
    toRational = toRational . toInteger

instance Integral Word256 where
    toInteger = Basement.toInteger
    quotRem a b = (Basement.quot a b, Basement.rem a b)

newtype UIntN (n :: Nat) = UIntN { unUIntN :: Word256 }
    deriving (Eq, Ord, Enum, Num, Bits, Generic)

instance (KnownNat n, n <= 256) => Show (UIntN n) where
    show = show . unUIntN

instance (KnownNat n, n <= 256) => Bounded (UIntN n) where
    minBound = 0
    maxBound = 2 ^ (natVal (Proxy :: Proxy n)) - 1

instance (KnownNat n, n <= 256) => Real (UIntN n) where
    toRational = toRational . toInteger

instance (KnownNat n, n <= 256) => Integral (UIntN n) where
    toInteger = toInteger . unUIntN
    quotRem (UIntN a) (UIntN b) = (UIntN $ quot a b, UIntN $ rem a b)

instance (n <= 256) => Hashable (UIntN n) where
    hashWithSalt s (UIntN (Word256 a b c d)) =
        s `hashWithSalt`
        a `hashWithSalt`
        b `hashWithSalt`
        c `hashWithSalt` d

instance (n <= 256) => ABIType (UIntN n) where
    isDynamic _ = False

instance (n <= 256) => ABIGet (UIntN n) where
    abiGet = UIntN <$> getWord256

instance (n <= 256) => ABIPut (UIntN n) where
    abiPut = putWord256 . unUIntN

-- TODO: Signed data type
newtype IntN (n :: Nat) = IntN { unIntN :: Word256 }
    deriving (Eq, Ord, Enum, Bits, Generic)

instance (KnownNat n, n <= 256) => Show (IntN n) where
    show = show . toInteger

instance (KnownNat n, n <= 256) => Bounded (IntN n) where
    minBound = negate $ 2 ^ (natVal (Proxy :: Proxy (n :: Nat)) - 1)
    maxBound = 2 ^ (natVal (Proxy :: Proxy (n :: Nat)) - 1) - 1

instance (KnownNat n, n <= 256) => Num (IntN n) where
    a + b  = fromInteger (toInteger a + toInteger b)
    a - b  = fromInteger (toInteger a - toInteger b)
    a * b  = fromInteger (toInteger a * toInteger b)
    abs    = fromInteger . abs . toInteger
    negate = fromInteger . negate . toInteger
    signum = fromInteger . signum . toInteger
    fromInteger x
      | x >= 0 = IntN (fromInteger x)
      | otherwise = IntN (fromInteger $ 2 ^ 256 + x)

instance (KnownNat n, n <= 256) => Real (IntN n) where
    toRational = toRational . toInteger

instance (KnownNat n, n <= 256) => Integral (IntN n) where
    quotRem (IntN a) (IntN b) = (IntN $ quot a b, IntN $ rem a b)
    toInteger x
      | testBit x 255 = toInteger (unIntN x) - 2 ^ 256
      | otherwise = toInteger $ unIntN x

instance (n <= 256) => ABIType (IntN n) where
    isDynamic _ = False

instance (n <= 256) => ABIGet (IntN n) where
    abiGet = IntN <$> getWord256

instance (n <= 256) => ABIPut (IntN n) where
    abiPut = putWord256 . unIntN

putWord256 :: Putter Word256
putWord256 (Word256 a3 a2 a1 a0) =
    put a3 >> put a2 >> put a1 >> put a0

getWord256 :: Get Word256
getWord256 = Word256 <$> get <*> get <*> get <*> get
