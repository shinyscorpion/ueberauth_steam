defmodule Ueberauth.Strategy.Steam do
  @moduledoc ~S"""
  Steam OpenID for Überauth.
  """

  use Ueberauth.Strategy

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Extra

  @doc ~S"""
  Handles initial request for Steam authentication.

  Redirects the given `conn` to the Steam login page.
  """
  @spec handle_request!(Plug.Conn.t) :: Plug.Conn.t
  def handle_request!(conn) do
    query =
      %{
        "openid.mode" => "checkid_setup",
        "openid.realm" => callback_url(conn),
        "openid.return_to" => callback_url(conn),
        "openid.ns" => "http://specs.openid.net/auth/2.0",
        "openid.claimed_id" => "http://specs.openid.net/auth/2.0/identifier_select",
        "openid.identity" => "http://specs.openid.net/auth/2.0/identifier_select",
      }
      |> URI.encode_query

    redirect!(conn, "https://steamcommunity.com/openid/login?" <> query)
  end

  @doc ~S"""
  Handles the callback from Steam.
  """
  @spec handle_callback!(Plug.Conn.t) :: Plug.Conn.t
  def handle_callback!(conn = %Plug.Conn{params: %{"openid.mode" => "id_res"}}) do
    params = conn.params

    [valid, user] =
      [ # Validate and retrieve the steam user at the same time.
        fn -> validate_user(params) end,
        fn -> retrieve_user(params) end,
      ]
      |> Enum.map(&Task.async/1)
      |> Enum.map(&Task.await/1)

    case valid && !is_nil(user) do
      true ->
        conn
        |> put_private(:steam_user, user)
      false ->
        set_errors!(conn, [error("invalid_user", "Invalid steam user")])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("invalid_openid", "Invalid openid response received")])
  end

  @doc false
  @spec handle_cleanup!(Plug.Conn.t) :: Plug.Conn.t
  def handle_cleanup!(conn) do
    conn
    |> put_private(:steam_user, nil)
  end

  @doc ~S"""
  Fetches the uid field from the response.

  Takes the `steamid` from the `steamuser` saved in the `conn`.
  """
  @spec uid(Plug.Conn.t) :: pos_integer
  def uid(conn) do
    conn.private.steam_user.steamid |> String.to_integer
  end

  @doc ~S"""
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.

  Takes the information from the `steamuser` saved in the `conn`.
  """
  @spec info(Plug.Conn.t) :: Info.t
  def info(conn) do
    user = conn.private.steam_user

    %Info{
      image: user.avatar,
      name: get_in(user, [:realname]),
      location: get_in(user, [:loccountrycode]),
      urls: %{
        Steam: user.profileurl,
      }
    }
  end

  @doc ~S"""
  Stores the raw information obtained from the Steam callback.

  Returns the `steamuser` saved in the `conn` as `raw_info`.
  """
  @spec extra(Plug.Conn.t) :: Extra.t
  def extra(conn) do
    %Extra{
      raw_info: %{
        user: conn.private.steam_user
      }
    }
  end

  @spec retrieve_user(map) :: map | nil
  defp retrieve_user(%{"openid.claimed_id" => "http://steamcommunity.com/openid/id/" <> id}) do
    key =
      :ueberauth
      |> Application.fetch_env!(Ueberauth.Strategy.Steam)
      |> Keyword.get(:api_key)
    url = "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=" <> key <> "&steamids=" <> id

    with {:ok, %HTTPoison.Response{body: body}} <- HTTPoison.get(url),
         {:ok, user} <- Poison.decode(body, keys: :atoms)
    do
      List.first(user.response.players)
    else
      _ -> nil
    end
  end

  @spec validate_user(map) :: boolean
  defp validate_user(params) do
    query =
      params
      |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "openid.") end)
      |> Enum.into(%{})
      |> Map.put("openid.mode", "check_authentication")
      |> URI.encode_query

    case HTTPoison.get("https://steamcommunity.com/openid/login?" <> query) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        String.contains?(body, "is_valid:true\n")
      _ ->
        false
    end
  end

  # Block undocumented function
  @doc false
  @spec default_options :: []
  def default_options

  @doc false
  @spec credentials(Plug.Conn.t) :: Ueberauth.Auth.Credentials.t
  def credentials(_conn), do: %Ueberauth.Auth.Credentials{}

  @doc false
  @spec auth(Plug.Conn.t) :: Ueberauth.Auth.t
  def auth(conn)
end
