![Elixir CI](https://github.com/tank-bohr/mmo/workflows/Elixir%20CI/badge.svg)

# MMO

## Prerequisite

- Erlang 23.1 (see [https://www.erlang.org/downloads/23.1](downloads page))
- Elixir 1.11.1 (see [installation instructions](https://elixir-lang.org/install.html) for more details)
- NodeJS (see [https://nodejs.org/en/download/](downloads page))


## Run the project

```
iex -S mix phx.server
```

## Run tests

```
mix tests
```

Add --cover option for test coverage generation

```
mix tests --cover
```

## Build the production release

```
mix deps.get
cd assets
npm install
npm run deploy
cd ..
mix phx.digest
MIX_ENV=prod mix release
```

## Deployment to gigalixir

See phoenix [guide](https://hexdocs.pm/phoenix/gigalixir.html) for more details

```
git push gigalixir master
```
