defmodule Ueberauth.Strategy.SteamTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Ueberauth.Strategy.Steam

  @sample_user %{avatar: "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe.jpg",
       avatarfull: "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe_full.jpg",
       avatarmedium: "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe_medium.jpg",
       communityvisibilitystate: 1, lastlogoff: 234234234, loccityid: 36148,
       loccountrycode: "NL", locstatecode: "03", personaname: "Sample",
       personastate: 0, personastateflags: 0,
       primaryclanid: "435345345", profilestate: 1,
       profileurl: "http://steamcommunity.com/id/sample/",
       realname: "Sample Sample", steamid: "765309403423",
       timecreated: 452342342}
  @sample_response %{response: %{players: [@sample_user]}}
  @optional_fields [:loccountrycode, :realname]

  describe "handle_request!" do
    test "redirects" do
      conn = Steam.handle_request! conn(:get, "http://example.com/path")

      assert conn.state == :sent
      assert conn.status == 302
    end

    test "redirects to the right url" do
      conn = Steam.handle_request! conn(:get, "http://example.com/path")

      {"location", location} = List.keyfind(conn.resp_headers, "location", 0)

      assert location == "https://steamcommunity.com/openid/login?openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.realm=http%3A%2F%2Fexample.com&openid.return_to=http%3A%2F%2Fexample.com"
    end
  end

  describe "handle_callback!" do
    setup do
      :meck.new Application, [:passthrough]
      :meck.expect Application, :fetch_env!, fn _, _ -> [api_key: "API_KEY"] end

      on_exit(fn -> :meck.unload end)

      :ok
    end

    defp callback(params \\ %{}) do
      conn = %{conn(:get, "http://example.com/path/callback") | params: params}

      Steam.handle_callback! conn
    end

    test "error for invalid callback parameters" do
      conn = callback()

      assert conn.assigns == %{
          ueberauth_failure: %Ueberauth.Failure{errors: [
            %Ueberauth.Failure.Error{message: "Invalid openid response received", message_key: "invalid_openid"}
          ], provider: nil, strategy: nil}
        }
    end

    test "error for missing user valid information" do
      :meck.new HTTPoison, [:passthrough]
      :meck.expect HTTPoison, :get, fn
        "https://steamcommunity.com/openid/login?openid.claimed_id=http%3A%2F%2Fsteamcommunity.com%2Fopenid%2Fid%2F12345&openid.mode=check_authentication" ->
          {:ok, %HTTPoison.Response{body: "", status_code: 200}}
        "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=API_KEY&steamids=12345" ->
          {:ok, %HTTPoison.Response{body: Poison.encode!(@sample_response), status_code: 200}}
      end

      conn =
        callback(%{
          "openid.mode" => "id_res",
          "openid.claimed_id" => "http://steamcommunity.com/openid/id/12345"
        })

      assert conn.assigns == %{
          ueberauth_failure: %Ueberauth.Failure{errors: [
            %Ueberauth.Failure.Error{message: "Invalid steam user", message_key: "invalid_user"}
          ], provider: nil, strategy: nil}
        }
    end

    test "error for invalid user callback" do
      :meck.new HTTPoison, [:passthrough]
      :meck.expect HTTPoison, :get, fn
        "https://steamcommunity.com/openid/login?openid.claimed_id=http%3A%2F%2Fsteamcommunity.com%2Fopenid%2Fid%2F12345&openid.mode=check_authentication" ->
          {:ok, %HTTPoison.Response{body: "is_valid:false\n", status_code: 200}}
        "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=API_KEY&steamids=12345" ->
          {:ok, %HTTPoison.Response{body: Poison.encode!(@sample_response), status_code: 200}}
      end

      conn =
        callback(%{
          "openid.mode" => "id_res",
          "openid.claimed_id" => "http://steamcommunity.com/openid/id/12345"
        })

      assert conn.assigns == %{
          ueberauth_failure: %Ueberauth.Failure{errors: [
            %Ueberauth.Failure.Error{message: "Invalid steam user", message_key: "invalid_user"}
          ], provider: nil, strategy: nil}
        }
    end

    test "error for invalid user data" do
      :meck.new HTTPoison, [:passthrough]
      :meck.expect HTTPoison, :get, fn
        "https://steamcommunity.com/openid/login?openid.claimed_id=http%3A%2F%2Fsteamcommunity.com%2Fopenid%2Fid%2F12345&openid.mode=check_authentication" ->
          {:ok, %HTTPoison.Response{body: "is_valid:true\n", status_code: 200}}
        "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=API_KEY&steamids=12345" ->
          {:ok, %HTTPoison.Response{body: "{{{{{{{", status_code: 200}}
      end

      conn =
        callback(%{
          "openid.mode" => "id_res",
          "openid.claimed_id" => "http://steamcommunity.com/openid/id/12345"
        })

      assert conn.assigns == %{
          ueberauth_failure: %Ueberauth.Failure{errors: [
            %Ueberauth.Failure.Error{message: "Invalid steam user", message_key: "invalid_user"}
          ], provider: nil, strategy: nil}
        }
    end

    test "success for valid user and valid user data" do
      :meck.new HTTPoison, [:passthrough]
      :meck.expect HTTPoison, :get, fn
        "https://steamcommunity.com/openid/login?openid.claimed_id=http%3A%2F%2Fsteamcommunity.com%2Fopenid%2Fid%2F12345&openid.mode=check_authentication" ->
          {:ok, %HTTPoison.Response{body: "is_valid:true\n", status_code: 200}}
        "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=API_KEY&steamids=12345" ->
          {:ok, %HTTPoison.Response{body: Poison.encode!(@sample_response), status_code: 200}}
      end

      conn =
        callback(%{
          "openid.mode" => "id_res",
          "openid.claimed_id" => "http://steamcommunity.com/openid/id/12345"
        })

      assert conn.assigns == %{}
      assert conn.private == %{steam_user: @sample_user}
    end
  end

  describe "info retrievers fetch" do
    setup do
      conn = %{conn(:get, "http://example.com/path/callback") | private: %{steam_user: @sample_user}}

      conn = Steam.handle_callback! conn

      [conn: conn]
    end

    test "uid", %{conn: conn} do
      assert Steam.uid(conn) == 765309403423
    end

    test "info", %{conn: conn} do
      assert Steam.info(conn) == %Ueberauth.Auth.Info{
             image: "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe.jpg",
             location: "NL", name: "Sample Sample",
             urls: %{Steam: "http://steamcommunity.com/id/sample/"}}
    end

    test "extra", %{conn: conn} do
      assert Steam.extra(conn) == %Ueberauth.Auth.Extra{raw_info: %{user: @sample_user}}
    end

    test "credentials", %{conn: conn} do
      assert Steam.credentials(conn) == %Ueberauth.Auth.Credentials{}
    end
  end

  describe "info retrievers fetch (nil optional fields)" do
    setup do
      conn = %{conn(:get, "http://example.com/path/callback") | private: %{steam_user: Map.drop(@sample_user, @optional_fields)}}
      conn = Steam.handle_callback! conn

      [conn: conn]
    end

    test "info", %{conn: conn} do
      auth_info = %Ueberauth.Auth.Info{
            image: "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe.jpg",
            urls: %{Steam: "http://steamcommunity.com/id/sample/"}}
      assert Steam.info(conn) == auth_info
    end
  end

  test "connection is cleaned up" do
    conn = %{conn(:get, "http://example.com/path/callback") | private: %{steam_user: @sample_user}}

    conn =
      conn
      |> Steam.handle_callback!
      |> Steam.handle_cleanup!

    assert conn.private == %{steam_user: nil}
  end
end
