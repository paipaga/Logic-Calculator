{-
   A simple purely functional parsing library
   Based on Chapter 8 of "Programming in Haskell" by Graham Hutton
   Pedro Vasconcelos, 2025
-}
module Parsing( Parser, parse, (<|>), failure, 
                satisfy, getc, char, many, many1 ) where

-- | the type of parsers:
--  "A parser for things
--   is a function from strings
--   to lists of pairs
--   of things and strings"

newtype Parser a
  = P (String -> [(a, String)])

-- all monads must also be functor
instance Functor Parser where
  fmap g (P f) = P (\s -> [(g x, s') | (x,s')<-f s])

-- | apply a parser
parse :: Parser a -> String -> [(a, String)]
parse (P f) s = f s

-- | Monad instance;
-- this allows us to use do-notation for combining parsers
instance Monad Parser where
  -- return :: a -> Parser a
  -- `return' should be defined as `pure' in GHC>=9.6.x
  return = pure 
  
  -- (>>=) :: Parser a -> (a -> Parser b) -> Parser b
  p >>= f = P (\s -> [(u,s'') | (v,s')<-parse p s, (u,s'')<-parse (f v) s'])

-- | the Monad class requires instances of Functor and Applicative
-- the later is defined bellow;
-- don't worry if you don't understand this!

instance Applicative Parser where
  pure x = P (\s -> [(x,s)]) 
  p <*> q = P (\s -> [(f v , s'')| (f,s') <- parse p s, (v,s'')<-parse q s'])


-- | alternative between two parsers
-- apply the first parser; if it succeeds return the result;
-- otherwise try the second parser
infixl 5 <|>

(<|>) :: Parser a -> Parser a -> Parser a
p <|> q = P (\s -> case parse p s of
                        [] -> parse q s
                        result -> result)   

-- | a parser that always fails
failure :: Parser a
failure = P (\s -> [])

-- | a parser that return the next character (if any)
getc :: Parser Char
getc = P (\s -> case s of
                  (x:xs) -> [(x, xs)]
                  []     -> [])

-- | parse a character that satisfies a predicate (boolean function)
satisfy :: (Char -> Bool) -> Parser Char
satisfy f = do
  x <- getc
  if f x then return x else failure

-- | parse a given character
char :: Char -> Parser Char
char c = satisfy (==c)

string :: String -> Parser ()
string []     = return ()
string (x:xs) = do char x; string xs
                   
-- | apply a parser zero or more times;
-- returns the list of results
many :: Parser a -> Parser [a]
many p = many1 p <|> return []

-- | apply a parser one or more times;
-- return the list of results
many1 :: Parser a -> Parser [a]
many1 p = do v <- p
             vs <- many p
             return (v:vs)

             