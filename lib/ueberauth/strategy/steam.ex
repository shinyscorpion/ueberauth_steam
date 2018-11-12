defmodule Ueberauth.Strategy.Steam do
  @moduledoc ~S"""
  Steam OpenID for Überauth.
  """

  use Ueberauth.Strategy
  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Extra
  
  defdelegate checkid_setup_url(callback_url), to: __MODULE__.OpenID
  defdelegate check_authentication(params), to: __MODULE__.OpenID
  defdelegate get_steam_user_id(claimed_id), to: __MODULE__.OpenID
  defdelegate get_steam_user(steam_user_id), to: __MODULE__.API

  @doc ~S"""
  Handles initial request for Steam authentication.

  Redirects the given `conn` to the Steam login page.
  """
  def handle_request!(conn) do
    redirect!(conn, checkid_setup_url(callback_url(conn)))
  end

  @doc ~S"""
  Handles the callback from Steam.
  """
  def handle_callback!(conn) do
    with \
      %{"openid.mode" => "id_res"} <- conn.params,
      {:ok, %{"openid.claimed_id" => claimed_id}} <- check_authentication(conn.params),
      {:ok, steam_user_id} <- get_steam_user_id(claimed_id),
      {:ok, steam_user} <- get_steam_user(steam_user_id)
    do
      conn |> put_private(:steam_user, steam_user)
    else
      {:error, :invalid_request} ->
        set_errors!(conn, [error("invalid_openid", "Invalid OpenID authentication request")])
      {:error, :invalid_user} ->
        set_errors!(conn, [error("invalid_user", "Invalid Steam user")])
      _ ->
        set_errors!(conn, [error("invalid_response", "Invalid response received")])
    end
  end
  
  @doc false
  def handle_cleanup!(conn) do
    conn |> put_private(:steam_user, nil)
  end
  
  @doc ~S"""
  Fetches the uid field from the response.

  Takes the information from `steam_user` saved in `conn`.
  """
  def uid(conn) do
    String.to_integer(conn.private.steam_user["steamid"])
  end
  
  @doc ~S"""
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.

  Takes the information from `steam_user` saved in `conn`.
  """
  def info(conn) do
    steam_user = conn.private.steam_user
    %Info{
      name: steam_user["realname"],
      nickname: steam_user["personaname"],
      image: steam_user["avatar"],
      location: steam_user["loccountrycode"],
      urls: %{
        steam_profile: steam_user["profileurl"]
      }
    }
  end

  @doc ~S"""
  Stores the raw information obtained from the Steam callback.

  Returns the `steamuser` saved in the `conn` as `raw_info`.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        user: conn.private.steam_user
      }
    }
  end
end
