# AutoFlow

Sistema local de gerenciamento de veículos, feito com Ruby + Sinatra + SQLite3.

## Executar

```bash
bundle install
ruby app.rb
```

Depois acesse `http://localhost:4567`.

A raiz `/` redireciona para `/veiculos`.

## Funcionalidades

- Cadastro, consulta, edição e exclusão de veículos
- Busca por marca, modelo, placa e proprietário
- Filtro por status
- Indicadores de inventário
- Página de detalhes
- Banco SQLite separado em `db/garagem.db`
- Interface responsiva com tema de gestão automotiva
