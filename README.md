# Überauth Steam

[![Hex.pm](https://img.shields.io/hexpm/v/ueberauth_steam.svg "Hex")](https://hex.pm/packages/ueberauth_steam)
[![Build Status](https://travis-ci.org/shinyscorpion/ueberauth_steam.svg?branch=master)](https://travis-ci.org/shinyscorpion/ueberauth_steam)
[![Coverage Status](https://coveralls.io/repos/github/shinyscorpion/ueberauth_steam/badge.svg?branch=master)](https://coveralls.io/github/shinyscorpion/ueberauth_steam?branch=master)
[![Inline docs](http://inch-ci.org/github/shinyscorpion/ueberauth_steam.svg?branch=master)](http://inch-ci.org/github/shinyscorpion/ueberauth_steam)
[![Deps Status](https://beta.hexfaktor.org/badge/all/github/shinyscorpion/ueberauth_steam.svg)](https://beta.hexfaktor.org/github/shinyscorpion/ueberauth_steam)
[![Hex.pm](https://img.shields.io/hexpm/l/ueberauth_steam.svg "License")](LICENSE)

> Steam OpenID strategy for Überauth.

## Installation

1. Obtain an Steam Web API Key at [Steam Dev](https://steamcommunity.com/login/home/?goto=%2Fdev%2Fapikey).

1. Add `:ueberauth_steam` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ueberauth_steam, "~> 0.1"}]
    end
    ```

1. Add the strategy to your applications:

    ```elixir
    def application do
      [applications: [:ueberauth_steam]]
    end
    ```

1. Add Steam to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        steam: {Ueberauth.Strategy.Steam, []}
      ]
    ```

1.  Update your provider configuration:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Steam,
      api_key: System.get_env("STEAM_API_KEY")
    ```

1.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller
      plug Ueberauth
      ...
    end
    ```

1.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

1. Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured URL you can initialize the request through:

    /auth/steam

## License

Please see [LICENSE](LICENSE) for licensing details.
