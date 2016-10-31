{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE GADTs           #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE TypeFamilies #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Miso.Html.Internal
-- Copyright   :  (C) 2016-2017 David M. Johnson
-- License     :  BSD3-style (see the file LICENSE)
-- Maintainer  :  David M. Johnson <djohnson.m@gmail.com>
-- Stability   :  experimental
-- Portability :  non-portable
----------------------------------------------------------------------------
module Miso.Html.Internal (
  -- * Core types and interface
    VTree  (..)
  , View   (..)
  , ToView (..)
  -- * Smart `View` constructors
  , node
  , text
  -- * Key patch internals
  , Key    (..)
  , ToKey  (..)
  , getKey
  , getKeyUnsafe
  -- * Namespace
  , NS     (..)
  -- * String type
  , MisoString
  , ToAction
  , MisoVal
  ) where

import qualified Data.Map            as M
import           Data.Text           (Text)
import qualified Data.Text           as T
import qualified Data.Vector         as V
import qualified Lucid               as L
import qualified Lucid.Base          as L

import           Miso.Html.Types
import           Miso.Html.String

type ToAction a = (() ~ ())

-- | Virtual DOM implemented as a Rose `Vector`.
--   Used for diffing, patching and event delegation.
--   Not meant to be constructed directly, see `View` instead.
data VTree action where
  VNode :: { vType :: Text -- ^ Element type (i.e. "div", "a", "p")
           , vNs :: NS -- ^ HTML or SVG
           , vEvents :: EventHandlers -- ^ Event Handlers
           , vProps :: Props -- ^ Fields present on DOM Node
           , vAttrs :: Attrs -- ^ Key value pairs present on HTML
           , vCss :: CSS -- ^ Styles
           , vKey :: Maybe Key -- ^ Key used for child swap patch
           , vChildren :: V.Vector (VTree action) -- ^ Child nodes
           } -> VTree action
  VText :: { vText :: Text -- ^ TextNode content
           } -> VTree action

instance Show (VTree action) where
  show = show . L.toHtml

-- | Converting `VTree` to Lucid's `L.Html`
instance L.ToHtml (VTree action) where
  toHtmlRaw = L.toHtml
  toHtml (VText x) = L.toHtml x
  toHtml VNode{..} =
    let ele = L.makeElement (toTag vType) kids
    in L.with ele as
      where
        Attrs xs = vAttrs
        as = [ L.makeAttribute k v | (k,v) <- M.toList xs ]
        toTag = T.toLower
        kids = foldMap L.toHtml vChildren

-- | Core type for constructing a `VTree`, use this instead of `VTree` directly.
newtype View action = View { runView :: VTree action }

-- | Convenience class for using View
class ToView v where
  toView :: v -> View action

-- | Show `View`
instance Show (View action) where
  show (View xs) = show xs

-- | Converting `View` to Lucid's `L.Html`
instance L.ToHtml (View action) where
  toHtmlRaw = L.toHtml
  toHtml (View xs) = L.toHtml xs

-- | Namespace for element creation
data NS
  = HTML -- ^ HTML Namespace
  | SVG  -- ^ SVG Namespace
  deriving (Show, Eq)

-- | `VNode` creation
node :: NS -> MisoString -> Maybe Key -> [Attribute action] -> [View action] -> View action
node vNs vType vKey as xs =
  let vEvents = EventHandlers [ x | E x <- as ]
      vProps  = Props  $ M.fromList [ (k,v) | P k v <- as ]
      vAttrs  = Attrs  $ M.fromList [ (k,v) | A k v <- as ]
      vCss    = CSS    $ M.fromList [ (k,v) | C k v <- as ]
      vChildren = V.fromList $ map runView xs
  in View VNode {..}

-- | `VText` creation
text :: MisoString -> View action
text x = View (VText x)

-- | Key for specific children patch
newtype Key = Key MisoString
  deriving (Show, Eq, Ord)

-- | Key lookup
getKey :: VTree action -> Maybe Key
getKey (VNode _ _ _ _ _ _ maybeKey _) = maybeKey
getKey _ = Nothing

-- | Unsafe Key extraction
getKeyUnsafe :: VTree action -> Key
getKeyUnsafe (VNode _ _ _ _ _ _ (Just key) _) = key
getKeyUnsafe _ = Prelude.error "Key does not exist"

-- | Convert type into Key, ensure `Key` is unique
class ToKey key where toKey :: key -> Key
-- | Identity instance
instance ToKey Key    where toKey = id
-- | Convert `Text` to `Key`
instance ToKey MisoString where toKey = Key
-- | Convert `String` to `Key`
instance ToKey String where toKey = Key . T.pack
-- | Convert `Int` to `Key`
instance ToKey Int    where toKey = Key . T.pack . show
-- | Convert `Double` to `Key`
instance ToKey Double where toKey = Key . T.pack . show
-- | Convert `Float` to `Key`
instance ToKey Float  where toKey = Key . T.pack . show
-- | Convert `Word` to `Key`
instance ToKey Word   where toKey = Key . T.pack . show
