module Main where

import Prelude

import Control.Monad
import Control.Monad.Eff
import Control.Monad.Eff.Random

import Data.Either
import qualified Data.Array as A
import Data.List
import Data.Int
import Data.Maybe
import Data.Maybe.Unsafe (fromJust)
import Data.Nullable (toMaybe)
import Unsafe.Coerce (unsafeCoerce)
import Text.Parsing.StringParser (ParseError(..))

import qualified Thermite as T

import qualified React as R
import qualified React.DOM as R
import qualified React.DOM.Props as RP

import qualified DOM as DOM
import qualified DOM.HTML as DOM
import qualified DOM.HTML.Document as DOM
import qualified DOM.HTML.Types as DOM
import qualified DOM.HTML.Window as DOM
import qualified DOM.Node.ParentNode as DOM
import qualified DOM.Node.Types as DOM

import State
import Language.Robo.Spec
import Language.Robo.Parser
import Language.Robo.Interpreter

initial :: Position -> Robot
initial pos =
  { instruction: 0
  , terminated: false
  , position: pos
  , parachute: pos }

initialCode = "start: left\nskip\ngoto start"

initialState :: State
initialState =
  { r1: initial (-3)
  , r2: initial 4
  , code: initialCode
  , parsed: false
  , program: Right Nil
  , running: false }

data Action = SetCode String
            | Randomize
            | Parse
            | Step
            | ToggleRunning

fa :: String -> _
fa str = R.i [ RP.className ("fa fa-" ++ str) ] []

foreign import data TIMER :: !
foreign import toggleInterval :: forall eff. Eff (timer :: TIMER | eff) Unit

render :: T.Render State _ Action
render dispatch _ state _ =
  [ R.div [ RP.className "canvas" ]
    [ R.div [ RP.className "robot1"
            , RP.style {left: show (screenPos state.r1.position) ++ "px", position: "absolute"} ] []
    , R.div [ RP.className "robot2"
            , RP.style {left: show (screenPos state.r2.position) ++ "px", position: "absolute"} ] []
    , R.div [ RP.className "parachute1"
            , RP.style {left: show (screenPos state.r1.parachute) ++ "px"} ] []
    , R.div [ RP.className "parachute2"
            , RP.style {left: show (screenPos state.r2.parachute) ++ "px"} ] []
    ]
  , R.div [ RP.className "panel" ]
      [ R.div [ RP.className "editor" ]
          [ R.textarea
            [ RP.autoFocus true
            , RP.rows "10"
            , RP.spellCheck "false"
            , RP.placeholder "Enter your code here..."
            , RP.onChange \e -> dispatch (SetCode (unsafeCoerce e).target.value) ]
            [ R.text initialCode ]
          ]
          , R.div [ RP.className "program" ]
          [ R.table' (programTable state.program state.r1.instruction state.r2.instruction) ]
      ]
  , R.div [ RP.className "buttons" ]
    [ R.button [ RP.onClick \_ -> dispatch Randomize
               , RP.disabled state.running ]
               [ fa "random", R.text " Randomize" ]
    , R.button [ RP.onClick \_ -> dispatch Parse
               , RP.disabled state.running ]
               [ fa "cogs", R.text " Parse" ]
    , R.button [ RP.disabled (not state.parsed)
               , RP._id "step"
               , RP.onClick \_ -> dispatch Step ]
               [ fa "step-forward", R.text " Step" ]
    , R.button [ RP.disabled (not state.parsed)
               , RP.onClick \_ -> dispatch ToggleRunning ]
               if state.running
                  then [ fa "stop", R.text " Stop" ]
                  else [ fa "play", R.text " Run" ]
    ]
  ]
  where screenPos :: Position -> Number
        screenPos p = 400.0 + 10.0 * toNumber p

mapIndexed :: forall a b. (Int -> a -> b) -> Array a -> Array b
mapIndexed f xs = A.zipWith f (A.range 0 (A.length xs)) xs

programTable :: Either ParseError Program -> Int -> Int -> _
programTable (Left (ParseError msg)) _ _ = [ R.tr' [ R.td' [ R.text ("Parse error: " ++ msg) ] ] ]
programTable (Right Nil) _ _ = []
programTable (Right program) i1 i2 = header `A.cons` mapIndexed row (fromList program)
  where header = R.tr'
                   [ R.th' [ R.text "R", R.sub' [ R.text "1" ] ]
                   , R.th' [ R.text "R", R.sub' [ R.text "2" ] ]
                   , R.th' [ R.text "Label" ]
                   , R.th' [ R.text "Instruction" ] ]
        row i (LInstruction label inst) =
          R.tr'
            [ R.td' [ R.div [ RP.className (if i == i1 then "robot1" else "") ] [] ]
            , R.td' [ R.div [ RP.className (if i == i2 then "robot2" else "") ] [] ]
            , R.td' [ R.text (fromMaybe "" label) ]
            , R.td' [ R.text (show inst) ]
            ]

performAction :: T.PerformAction _ State _ Action
performAction (SetCode code) _ state update = do
  when state.running toggleInterval
  update $ state { code = code, parsed = false, program = Right Nil, running = false }
performAction Randomize _ state update = do
  p1 <- randomInt 0 20
  delta <- randomInt 1 19
  let p2 = (p1 + delta) `mod` 20
  update $ state { r1 = initial (p1 - 10), r2 = initial (p2 - 10) }
performAction Parse _ state update = update $
  state { parsed = isRight program
        , program = program
        , r1 = state.r1 { instruction = 0 }
        , r2 = state.r2 { instruction = 0 }
        }
  where program = parseRobo state.code
performAction Step _ state update = update $
  state { r1 = either (const state.r1) (\p -> step p state.r2.parachute state.r1) state.program
        , r2 = either (const state.r2) (\p -> step p state.r1.parachute state.r2) state.program }
performAction ToggleRunning _ state update = do
  toggleInterval
  update $ state { running = not state.running }

spec :: T.Spec _ State _ Action
spec = T.simpleSpec performAction render

main = void do
  let component = T.createClass spec initialState
  document <- DOM.window >>= DOM.document
  container <- fromJust <<< toMaybe <$> DOM.querySelector "#container" (DOM.htmlDocumentToParentNode document)
  R.render (R.createFactory component {}) container
