# Logical calculator in Haskell

Reads propositions from standard input, one per line, and classifies each one as `TAUTOLOGY`, `CONTRADICTION` or `CONTINGENT`.

## How to use

You need GHC. `Prop.hs` and `Parsing.hs` must be in the same directory.

### Run on a file

```
runghc Prop.hs < input.txt
```

### Type the input by hand

```
runghc Prop.hs
```

Type one proposition per line, and press `Ctrl+D` to finish.

### Compile

```
ghc -o prop Prop.hs
./prop < input.txt
```

### Use GHCi

GHCi lets you classify a single proposition or see its parse tree:

```
ghci Prop.hs
ghci> evaluate "a&b|c"
"CONTINGENT"
ghci> parse prop "a&b|c"
[(Or (And (Var 'a') (Var 'b')) (Var 'c'),"")]
```

### Input syntax

| Symbol | Meaning |
|---|---|
| `a` to `z` | variable |
| `T`, `F` | true, false |
| `!` | negation |
| `&` | conjunction |
| `\|` | disjunction |
| `(` `)` | grouping |

- From highest to lowest, the precedence is `!`, `&`, `|`.
- `&` and `|` are left-associative.
- Spaces are not allowed, so `a & b` is a parse error.

### Output

The program writes one line for each line of input:

| Output | Meaning |
|---|---|
| `TAUTOLOGY` | true for every assignment of the variables |
| `CONTRADICTION` | false for every assignment of the variables |
| `CONTINGENT` | true for some assignments and false for others |
| `parse error; try again` | the line is not a valid proposition |

### Example

Input:

```
T
a&F
a
a|!a
!p&!!p
p&T|p
p|!p&q
p&!p&p
!(p&q)|p
```

Output:

```
TAUTOLOGY
CONTRADICTION
CONTINGENT
TAUTOLOGY
CONTRADICTION
CONTINGENT
CONTINGENT
CONTRADICTION
TAUTOLOGY
```

## How it works

Each line goes through the same pipeline: **text → `Prop` (parser) → truth table → classification**.

### 1. Types ([lines 7-15](Prop.hs#L7-L15))

- **`Prop`:** the tree of a proposition. For example, `a&T` becomes `And (Var 'a') (Const True)`.
- **`Name`:** the name of a variable, which is a `Char`.
- **`Env`:** an assignment of values to variables, for example `[('a',True),('b',False)]`.

### 2. Parser

A `Parser Prop` tries to read a `Prop` from the start of a string, and returns what it read and what was left over. For example, `parse prop "a&b"` gives `[(And (Var 'a') (Var 'b'), "")]`.

Two rules from `Parsing.hs` explain almost everything:

- **In a `do` block:** if one step fails, the whole block fails.
- **In `p <|> q`:** if `p` fails, `q` is tried from the point where `p` started.

#### `factor` ([line 37](Prop.hs#L37))

This is the smallest unit. It tries five alternatives in order:

1. **`!`:** reads another `factor` and returns `Not f`. It is recursive, so `!!a` works.
2. **Lowercase letter:** returns `Var x`.
3. **`T`:** returns `Const True`.
4. **`F`:** returns `Const False`.
5. **`(`:** reads a complete `prop`, requires `)` and returns what was inside. Parentheses do not appear in the tree.

#### `term` and `termCont` ([lines 27-35](Prop.hs#L27-L35))

- **`term`:** reads the first `factor` and passes it to `termCont`.
- **`termCont acc`:** `acc` is the tree built so far.
  - If the next character is `&`, it reads another `factor` and continues with `And acc f`.
  - Otherwise, it returns `acc`.

For `a&b&c`, the accumulator evolves as follows, which is what makes `&` left-associative:

```
acc = a
acc = And a b
acc = And (And a b) c
```

#### `prop` and `propCont` ([lines 17-25](Prop.hs#L17-L25))

These do the same with `|` and `Or`, but they read `term`s instead of `factor`s. Each `term` has already consumed all of its `&`s, which gives `&` higher precedence than `|`.

#### Full example: `a&b|c`

| Step | Function | Reads | Result | Left over |
|---|---|---|---|---|
| 1 | `factor` | `a` | `Var a` | `&b\|c` |
| 2 | `termCont` | `&b` | `And a b` | `\|c` |
| 3 | `termCont` | no `&` (sees `\|`) | returns `And a b` | `\|c` |
| 4 | `propCont` | `\|` and the `term` `c` | `Or (And a b) c` | empty |
| 5 | `propCont` | no `\|` (end of input) | returns the tree | empty |

### 3. Evaluation

#### `eval` ([line 57](Prop.hs#L57))

Computes the value of a `Prop` under an assignment, with one case per constructor:

- **`Const b`:** returns `b`.
- **`Var x`:** looks up `x` in `env` with `lookup`, which returns `Just b` or `Nothing`.
- **`Not`, `And`, `Or`:** evaluates the subtrees and applies `not`, `&&` or `||`.

The `Nothing` case never happens here, because `table` generates assignments that contain every variable of the proposition.

#### `vars` ([line 69](Prop.hs#L69))

Walks the tree and collects all the variables. The result can contain duplicates: `a|!a` gives `"aa"`. That is why `table` uses `nub`.

#### `booleans` ([line 76](Prop.hs#L76))

Generates all combinations of `n` booleans, which is 2ⁿ lists:

- **Base case:** `booleans 0 = [[]]` is a list with one empty combination.
- **Recursive case:** takes the combinations for `n-1`, appends `False` to each one, then appends `True` to each one, and joins the two lists.

```
booleans 1 = [[F], [T]]
booleans 2 = [[F,F], [T,F], [F,T], [T,T]]
```

#### `environments` ([line 80](Prop.hs#L80))

Pairs the variable names with each combination using `zip`. For `"ab"`:

```
[ [(a,F),(b,F)], [(a,T),(b,F)], [(a,F),(b,T)], [(a,T),(b,T)] ]
```

With no variables it gives `[[]]`, a single empty assignment. This way, `T` and `F` are evaluated once.

#### `table` ([line 83](Prop.hs#L83))

Builds the truth table:

1. `vars p` lists the variables.
2. `nub` removes the duplicates.
3. `environments` generates the assignments.
4. For each assignment, it keeps the pair `(env, eval env p)`.

#### `satisfies` ([line 86](Prop.hs#L86))

Returns only the assignments that make the proposition true. The classification does not use it, but you can call it in GHCi.

### 4. Classification

#### `classify` ([line 89](Prop.hs#L89))

`map snd` keeps only the results column of the table. The conditions are then tested in order:

| Condition | Meaning | Example | `results` | Output |
|---|---|---|---|---|
| `and results` | all true | `a\|!a` | `[T,T]` | `TAUTOLOGY` |
| `not (or results)` | none true | `a&F` | `[F,F]` | `CONTRADICTION` |
| `otherwise` | a mix of both | `a` | `[F,T]` | `CONTINGENT` |

### 5. Input and output

#### `evaluate` ([line 101](Prop.hs#L101))

Runs the parser on one line and checks the result:

- **`[(tree, "")]`:** the parse succeeded and consumed everything, so it classifies the tree.
- **Anything else:** returns the error message.

This check on the left-over input is essential. In `a&`, `termCont` reads the `&` but `factor` fails, so `<|>` backtracks and returns `Var a` with `"&"` left over. The parse does not fail on its own, and only the check for `""` catches the error.

#### `calculator` ([line 96](Prop.hs#L96))

Goes through the list of lines recursively. If the list is empty, it stops. Otherwise, it prints the result for the first line with `putStrLn` and continues with the rest.

#### `main` ([line 107](Prop.hs#L107))

`getContents` reads all of standard input, `lines` splits it into lines, and `calculator` handles them.
