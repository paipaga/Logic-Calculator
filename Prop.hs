module Main where

import Parsing
import Data.Char (isLower)
import Data.List (nub)

data Prop = Const Bool
            | Var Name
            | Not Prop
            | And Prop Prop
            | Or Prop Prop
    deriving (Show, Eq)

type Name = Char
type Env = [(Name, Bool)]

prop :: Parser Prop
prop = do t <- term
          propCont t

propCont :: Prop -> Parser Prop
propCont acc = do char '|'
                  t <- term
                  propCont (Or acc t)
               <|> return acc

term :: Parser Prop
term = do f <- factor
          termCont f

termCont :: Prop -> Parser Prop
termCont acc = do char '&'
                  f <- factor
                  termCont (And acc f)
               <|> return acc

factor :: Parser Prop
factor = do char '!'
            f <- factor
            return (Not f)
         <|>
         do x <- satisfy isLower
            return (Var x)
         <|>
         do char 'T'
            return (Const True)    -- same as function constant
         <|>
         do char 'F'
            return (Const False)
         <|>
         do char '('
            p <- prop
            char ')'
            return p

-- Functions eval, vars, booleans environments table and satisfies were mad in class (Worksheet 5)
eval :: Env -> Prop -> Bool
eval env (Const b) = b
eval env (Var x) =
  case lookup x env of
    Just b -> b
    Nothing -> error "undefined variable"
eval env (Not p) = not (eval env p)
eval env (And p q) =
  eval env p && eval env q
eval env (Or p q) =
  eval env p || eval env q

vars :: Prop -> [Name]
vars (Const _) = []
vars (Var p) = [p]
vars (Not p) = vars p
vars (And p q) = vars p ++ vars q
vars (Or p q) = vars p ++ vars q

booleans :: Int -> [[Bool]]
booleans 0 = [[]]
booleans n = map (++ [False]) (booleans (n - 1)) ++ map (++ [True]) (booleans (n - 1))

environments :: [Name] -> [Env]
environments names = map (zip names) (booleans (length names))

table :: Prop -> [(Env, Bool)]
table p = [(env, eval env p) | env <- environments (nub (vars p))]

satisfies :: Prop -> [Env]
satisfies p = [env | env <- environments (nub (vars p)), eval env p]

classify :: Prop -> String
classify p
  | and results = "TAUTOLOGY"
  | not (or results) = "CONTRADICTION"
  | otherwise = "CONTINGENT"
  where results = map snd (table p)

calculator :: [String] -> IO ()
calculator [] = return ()
calculator (l:ls) = do putStrLn (evaluate l)
                       calculator ls

evaluate :: String -> String
evaluate txt
  = case parse prop txt of
      [(tree, "")] -> classify tree
      _ -> "parse error; try again"

main :: IO ()
main
  = do txt <- getContents
       calculator (lines txt)