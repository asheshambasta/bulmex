{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecursiveDo       #-}

-- | Bulma loading screen w/ help of extension:
--   https://wikiki.github.io/elements/pageloader/
module Reflex.Bulmex.Load
  ( withReadyEvt, postpone, getReady, prerenderLoad, pageLoader
  ) where

import           Control.Monad              (void)
import           Control.Monad.IO.Class     (MonadIO)
import qualified Data.Text                  as Text
import           Reflex
import           Reflex.Bulmex.Event
import           Reflex.Bulmex.Tag.Abstract
import           Reflex.Dom.Builder.Class
import           Reflex.Dom.Prerender
import qualified Reflex.Dom.Widget.Basic    as Dom
import qualified Reflex.Tags                as T

pageLoader :: DomBuilder t m => Text.Text -> m a -> m a
pageLoader = partialDiv "pageloader"

postpone :: (DomBuilder t m, MonadHold t m) => Event t () -> m () -> m ()
postpone evt m = holdEvent_ evt (const m)

-- | This doesn't work always,
--   When finished use: https://github.com/reflex-frp/reflex-dom/pull/273
--   postbuild is imediate for sampling, adding a delay makes it after
--   widget completes see: https://github.com/reflex-frp/reflex-dom-semui/issues/18
getReady ::
     ( PostBuild t m
     , PerformEvent t m
     , TriggerEvent t m
     , MonadIO (Performable m)
     )
  => m (Event t ())
getReady = getPostBuild >>= delay 0

-- | attach the ready event to the widget, which fires once it's usuable
withReadyEvt ::
     ( PostBuild t m
     , PerformEvent t m
     , TriggerEvent t m
     , MonadIO (Performable m)
     )
  => m b
  -> m (b, Event t ())
withReadyEvt mb = do
  res <- mb
  evt <- getReady
  pure (res, evt)

-- | show a spinning image while loading JS
prerenderLoad :: (Prerender js t m,  DomBuilder t m) => m () -> m ()
prerenderLoad spinner = void $ prerender (T.divClass "prerender-load" $ spinner) Dom.blank
