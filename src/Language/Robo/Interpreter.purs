module Language.Robo.Interpreter
  ( step
  ) where

import Prelude

import Data.List
import Data.Maybe

import Language.Robo.Spec
import State

-- | Run a single instruction of the program for a given robot state
step :: Program -> Position -> Robot -> Robot
step program otherParachute st =
  case (index program st.instruction) of
    Just (LInstruction _ instr) -> eval instr
    Nothing -> st { terminated = true }

  where
    eval MoveRight =
      st { position = st.position + 1 , instruction = st.instruction + 1 }
    eval MoveLeft =
      st { position = st.position - 1 , instruction = st.instruction + 1 }
    eval SkipIfParachute =
      st { instruction =
             if st.position == st.parachute || st.position == otherParachute
               then st.instruction + 2
               else st.instruction + 1 }
    eval (Goto label) =
      st { instruction = findInstruction label }

    findInstruction label =
      fromMaybe (-1) $ findIndex (\(LInstruction mlabel _) -> mlabel == Just label) program
