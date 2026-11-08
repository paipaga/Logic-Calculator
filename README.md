# Calculadora lógica em Haskell

Lê proposições do stdin, uma por linha, e classifica cada uma como `TAUTOLOGY`, `CONTRADICTION` ou `CONTINGENT`.

O programa faz isto a cada linha: **texto → `Prop` (parser) → tabela de verdade → classificação**.

## Como correr

```
runghc Prop.hs < input.txt
```

## 1. Tipos ([linhas 7-15](Prop.hs#L7-L15))

- **`Prop`:** é a árvore de uma proposição. Por exemplo, `a&T` fica `And (Var 'a') (Const True)`.
- **`Name`:** é o nome de uma variável, ou seja, um `Char`.
- **`Env`:** é uma atribuição de valores às variáveis, por exemplo `[('a',True),('b',False)]`.

## 2. Parser

Um `Parser Prop` tenta ler uma `Prop` do início da string e devolve o que leu e o que sobrou. Por exemplo, `parse prop "a&b"` dá `[(And (Var 'a') (Var 'b'), "")]`.

Duas regras do `Parsing.hs` explicam quase tudo:

- **Num `do`:** se um passo falha, o bloco inteiro falha.
- **Em `p <|> q`:** se `p` falha, tenta `q` a partir do ponto onde `p` começou.

### `factor` ([linha 39](Prop.hs#L39))

É a unidade mais pequena, e tenta cinco alternativas por ordem:

1. **`!`:** lê outro `factor` e devolve `Not f`. É recursivo, por isso `!!a` funciona.
2. **Letra minúscula:** devolve `Var x`.
3. **`T`:** devolve `Const True`.
4. **`F`:** devolve `Const False`.
5. **`(`:** lê uma `prop` completa, exige `)` e devolve o que está lá dentro. Os parênteses não ficam na árvore.

### `term` e `termCont` ([linhas 28-37](Prop.hs#L28-L37))

- **`term`:** lê o primeiro `factor` e passa-o ao `termCont`.
- **`termCont acc`:** `acc` é a árvore construída até agora.
  - Se vier `&`, lê outro `factor` e continua com `And acc f`.
  - Se não vier, devolve `acc`.

Para `a&b&c`, o acumulador evolui assim, e é isto que dá a associatividade à esquerda:

```
acc = a
acc = And a b
acc = And (And a b) c
```

### `prop` e `propCont` ([linhas 17-26](Prop.hs#L17-L26))

Fazem o mesmo com `|` e `Or`, mas lendo `term`s em vez de `factor`s. Como cada `term` já consumiu todos os seus `&`, o `&` tem precedência sobre o `|`.

### Exemplo completo: `a&b|c`

| Passo | Quem | Lê | Resultado | Sobra |
|---|---|---|---|---|
| 1 | `factor` | `a` | `Var a` | `&b\|c` |
| 2 | `termCont` | `&b` | `And a b` | `\|c` |
| 3 | `termCont` | falha no `&` (vê `\|`) | devolve `And a b` | `\|c` |
| 4 | `propCont` | `\|` e o `term` `c` | `Or (And a b) c` | vazio |
| 5 | `propCont` | falha no `\|` (fim) | devolve a árvore | vazio |

## 3. Avaliação

### `eval` ([linha 58](Prop.hs#L58))

Calcula o valor de uma `Prop` numa atribuição, com um caso por construtor:

- **`Const b`:** devolve `b`.
- **`Var x`:** procura `x` no `env` com `lookup`, que devolve `Just b` ou `Nothing`.
- **`Not`, `And`, `Or`:** avalia as subárvores e aplica `not`, `&&` ou `||`.

O caso `Nothing` nunca acontece aqui, porque `table` gera atribuições com todas as variáveis da proposição.

### `vars` ([linha 70](Prop.hs#L70))

Percorre a árvore e junta todas as variáveis. Pode haver repetidos: `a|!a` dá `"aa"`. É por isso que `table` usa `nub`.

### `booleans` ([linha 77](Prop.hs#L77))

Gera todas as combinações de `n` booleanos, ou seja, 2ⁿ listas:

- **Caso base:** `booleans 0 = [[]]` é uma lista com uma combinação vazia.
- **Caso recursivo:** pega nas combinações de `n-1`, acrescenta `False` a cada uma, depois `True`, e junta as duas listas.

```
booleans 1 = [[F], [T]]
booleans 2 = [[F,F], [T,F], [F,T], [T,T]]
```

### `environments` ([linha 81](Prop.hs#L81))

Associa os nomes das variáveis a cada combinação com `zip`. Para `"ab"`:

```
[ [(a,F),(b,F)], [(a,T),(b,F)], [(a,F),(b,T)], [(a,T),(b,T)] ]
```

Sem variáveis, dá `[[]]`, ou seja, uma única atribuição vazia. Assim, `T` e `F` são avaliados uma vez.

### `table` ([linha 84](Prop.hs#L84))

É a tabela de verdade:

1. `vars p` lista as variáveis.
2. `nub` tira os repetidos.
3. `environments` gera as atribuições.
4. Para cada uma, guarda o par `(env, eval env p)`.

## 4. Classificação

### `classify` ([linha 87](Prop.hs#L87))

`map snd` fica só com a coluna dos resultados da tabela, e depois testa por ordem:

| Condição | Significado | Exemplo | `results` | Saída |
|---|---|---|---|---|
| `and results` | todos verdadeiros | `a\|!a` | `[T,T]` | `TAUTOLOGY` |
| `not (or results)` | nenhum verdadeiro | `a&F` | `[F,F]` | `CONTRADICTION` |
| `otherwise` | há dos dois | `a` | `[F,T]` | `CONTINGENT` |

## 5. Entrada e saída

### `evaluate` ([linha 101](Prop.hs#L101))

Corre o parser sobre uma linha e vê o resultado:

- **`[(tree, "")]`:** o parse funcionou e consumiu tudo, por isso classifica a árvore.
- **Qualquer outro caso:** escreve a mensagem de erro.

Este teste ao resto é essencial. Em `a&`, o `termCont` lê o `&`, mas o `factor` falha, por isso o `<|>` recua e devolve `Var a` com resto `"&"`. O parse não falha por si, e só a verificação do resto `""` apanha o erro.

### `calculator` ([linha 96](Prop.hs#L96))

Percorre a lista de linhas recursivamente. Se estiver vazia, termina. Caso contrário, escreve o resultado da primeira linha com `putStrLn` e continua com as restantes.

### `main` ([linha 107](Prop.hs#L107))

`getContents` lê todo o stdin, `lines` parte-o em linhas e `calculator` trata delas.
