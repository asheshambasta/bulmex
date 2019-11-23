{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecursiveDo       #-}
{-# LANGUAGE TypeFamilies      #-}

-- | This makes it easy to create auto-save operations
--   not limited to saves.
module Reflex.Bulmex.Input.Debounce
  ( InputStates(..)
  , defStateAttr
  , withInputDebounceEvt
  , withInput
  ) where

import           Control.Monad.Fix
import           Control.Monad.IO.Class (MonadIO)
import qualified Data.Text              as Text
import           Data.Time
import           Reflex
import           Reflex.Bulmex.Event

-- | Allows widgets to react according with what's happening
data InputStates
  = InputStarted
  | InputBuffered
  | InputProcessed
  | InputAborted
  | InputInitial

-- | do a debounced request, create a widget with the attrmap that
--  indicates the state of doing the request
--  This allows you to automatically send stuff to server once user is
--  finished with typing, while not flooding the server with requests
withInputDebounceEvt ::
     ( PostBuild t m
     , MonadFix m
     , MonadHold t m
     , TriggerEvent t m
     , MonadIO (Performable m)
     , PerformEvent t m)
  => NominalDiffTime -> -- ^ Delay before posting the request
  (result -> Bool) -- ^ Was the final requess successfull?
  -> (Dynamic t InputStates -> m (b, Event t inputEvt)) -- ^ Widget body reacting to states
  -> (b -> Event t inputEvt -> m (Event t result)) -- ^ Action function
  -> m (Event t result, b)
withInputDebounceEvt debtime succF stateF = withInput (debounce debtime) succF $
    const $ fmap (\(one',two) -> (one', two, one')) . stateF

-- | Maps input state to bulmex classes: InputStarted = is-warning for example
defStateAttr :: InputStates -> Text.Text
defStateAttr  InputStarted   = "is-warning"
defStateAttr  InputBuffered  = "is-warning" -- is-loading
defStateAttr  InputProcessed = "is-success"
defStateAttr  InputAborted   = "is-danger"
defStateAttr  InputInitial   = ""

-- | A general debounce widget
--  This looks a lot like 'actionForm', but it's not the same because
--  form allows user code to decide what
withInput ::
     ( PostBuild t m
     , MonadFix m
     , MonadHold t m
     ) =>
  (Event t inputEvt -> m (Event t inputEvt)) -- ^ change input timeline, eg pure for no change
  -> (result -> Bool) -- ^ Was the final requess successfull?
  -> (Event t result -> Dynamic t InputStates -> m (actArgs, Event t inputEvt, finalRes)) -- ^ Widget body reacting to states
  -> (actArgs -> Event t inputEvt -> m (Event t result)) -- ^ Action function
  -> m (Event t result, finalRes)
withInput timeF isSuccessF createTypeEvt reqFunc =
  mdo (someData, typeEvtImmediate, result) <- createTypeEvt postFinished areaState
      typeEvtDeb <- timeF typeEvtImmediate
      postFinished <- reqFunc someData typeEvtDeb
      areaState <-
        holdDyn InputInitial $
        leftmost $
          [ InputStarted <$ typeEvtImmediate
          , InputBuffered  <$ typeEvtDeb
          , InputProcessed  <$ (blockFalse $ isSuccessF <$> postFinished)
          , InputAborted  <$ (blockFalse $ not . isSuccessF <$> postFinished)
          ]
      pure (postFinished, result)
