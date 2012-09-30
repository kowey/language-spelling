{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Language.Distance.Search.BK (BKTree) where

import           Data.Word (Word8)

import           Data.IntMap (IntMap)
import qualified Data.IntMap as IntMap
import           Data.ByteString (ByteString)

import           Data.ListLike (ListLike)

import           Language.Distance
import           Language.Distance.Search.Class

data BKTree full sym algo = EmptyBK
                          | BKTree !full !(IntMap (BKTree full sym algo))

narrow :: IntMap.Key -> IntMap.Key -> IntMap a -> IntMap a
narrow n m im = fst (IntMap.split m (snd (IntMap.split n im)))

instance (Eq sym, ListLike full sym, EditDistance sym algo)
         => Search (BKTree full sym algo) full algo where
    empty = EmptyBK
    insert = insertBK
    {-# SPECIALISE insert :: String -> BKTree String Char Levenshtein
                          -> BKTree String Char Levenshtein #-}
    {-# SPECIALISE insert :: String -> BKTree String Char DamerauLevenshtein
                          -> BKTree String Char DamerauLevenshtein #-}
    {-# SPECIALISE insert :: ByteString -> BKTree ByteString Word8 Levenshtein
                          -> BKTree ByteString Word8 Levenshtein #-}
    {-# SPECIALISE insert :: ByteString -> BKTree ByteString Word8 DamerauLevenshtein
                          -> BKTree ByteString Word8 DamerauLevenshtein #-}


    query _    _    EmptyBK          = []
    query maxd str (BKTree str' bks) = match ++ concatMap (query maxd str) children
      where dist = distance str str'
            intDist = getDistance dist
            match | intDist <= maxd = [(str', dist)]
                  | otherwise       = []
            children = IntMap.elems $ narrow (abs (intDist - maxd)) (intDist + maxd) bks
    {-# SPECIALISE query :: Int -> String -> BKTree String Char Levenshtein
                         -> [(String, Distance Levenshtein)] #-}
    {-# SPECIALISE query :: Int -> String -> BKTree String Char DamerauLevenshtein
                         -> [(String, Distance DamerauLevenshtein)] #-}
    {-# SPECIALISE query :: Int -> ByteString -> BKTree ByteString Word8 Levenshtein
                         -> [(ByteString, Distance Levenshtein)] #-}
    {-# SPECIALISE query :: Int -> ByteString -> BKTree ByteString Word8 DamerauLevenshtein
                         -> [(ByteString, Distance DamerauLevenshtein)] #-}


insertBK :: forall full sym algo. (Eq sym, EditDistance sym algo, ListLike full sym)
         => full -> BKTree full sym algo -> BKTree full sym algo
insertBK str EmptyBK = BKTree str IntMap.empty
insertBK str bk@(BKTree str' bks)
    | dist == 0 = bk
    | otherwise = BKTree str' $ flip (IntMap.insert dist) bks $
                  maybe (singleton str) (insertBK str) (IntMap.lookup dist bks)
  where dist = getDistance (distance str str' :: Distance algo)
