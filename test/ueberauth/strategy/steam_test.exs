defmodule Ueberauth.Strategy.SteamTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Ueberauth.Strategy.Steam

  @sample_user %{
    "avatar" => "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe.jpg",
    "avatarfull" => "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe_full.jpg",
    "avatarmedium" => "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/f3/f3dsf34324eawdasdas3rwe_medium.jpg",
    "communityvisibilitystate" => 1,
    "lastlogoff" => 234234234,
    "loccityid" => 36148,
    "loccountrycode" => "NL",
    "locstatecode" => "03",
    "personaname" => "Sample",
    "personastate" => 0,
    "personastateflags" => 0,
    "primaryclanid" => "435345345",
    "profilestate" => 1,
    "profileurl" => "http://steamcommunity.com/id/sample/",
    "realname" => "Sample Sample",
    "steamid" => "765309403423",
    "timecreated" => 452342342
  }
  @sample_response %{
    "response" => %{
      "players" => [@sample_user]
    }
  }

  describe "handle_request!" do
    test "redirects" do
      conn = Steam.handle_request! conn(:get, "http://example.com/path")
      assert conn.state == :sent
      assert conn.status == 302
    end

    test "redirects to the right url" do
      conn = Steam.handle_request! conn(:get, "http://example.com/path")
      {"location", location} = List.keyfind(conn.resp_headers, "location", 0)
      location_url = URI.parse(location)
      location_query = URI.decode_query(location_url.query)
      assert %{host: "steamcommunity.com", path: "/openid/login", scheme: "https"} = location_url
      assert %{
        "openid.realm" => "http://example.com",
        "openid.return_to" => "http://example.com"
      } = location_query
    end
  end

  describe "handle_callback!" do
    setup do
      on_exit(&:meck.unload/0)
      :meck.new(Application, [:passthrough])
      :meck.expect(Application, :fetch_env, fn :ueberauth, Ueberauth.Strategy.Steam ->
        {:ok, [api_key: "API_KEY"]}
      end)
      [
        mock: fn auth_resp, user_resp ->
          :meck.new HTTPoison, [:passthrough]
          :meck.expect(HTTPoison, :get, fn
            "https://steamcommunity.com/openid/login", _, _ ->
              {:ok, %HTTPoison.Response{body: auth_resp, status_code: 200}}
            "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002", _, _ ->
              {:ok, %HTTPoison.Response{body: user_resp, status_code: 200}}
          end)
        end,
        payload: %{
          "openid.mode" => "id_res",
          "openid.claimed_id" => "http://steamcommunity.com/openid/id/12345"
        }
      ]
    end

    defp callback(params \\ %{}) do
      conn = %{conn(:get, "http://example.com/path/callback") | params: params}
      Steam.handle_callback! conn
    end

    test "error for invalid callback parameters" do
      conn = callback()
      assert %{ueberauth_failure: %{errors: [%{message_key: "invalid_request"}]}} = conn.assigns
    end

    test "error for missing user valid information", context do
      context.mock.("", Poison.encode!(@sample_response))
      conn = callback(context.payload)
      assert %{ueberauth_failure: %{errors: [%{message_key: "invalid_openid"}]}} = conn.assigns
    end

    test "error for invalid user callback", context do
      context.mock.("ns:http://specs.openid.net/auth/2.0\nis_valid:false\n", Poison.encode!(@sample_response))
      conn = callback(context.payload)
      assert %{ueberauth_failure: %{errors: [%{message_key: "invalid_openid"}]}} = conn.assigns
    end

    test "error for invalid user data", context do
      context.mock.("ns:http://specs.openid.net/auth/2.0\nis_valid:true\n", "{{{{{{{")
      conn = callback(context.payload)
      assert %{ueberauth_failure: %{errors: [%{message_key: "invalid_user"}]}} = conn.assigns
    end

    test "success for valid user and valid user data", context do
      context.mock.("ns:http://specs.openid.net/auth/2.0\nis_valid:true\n", Poison.encode!(@sample_response))
      conn = callback(context.payload)
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
        location: "NL",
        name: "Sample Sample",
        nickname: "Sample",
        urls: %{steam_profile: "http://steamcommunity.com/id/sample/"}
      }
    end

    test "extra", %{conn: conn} do
      assert Steam.extra(conn) == %Ueberauth.Auth.Extra{raw_info: %{user: @sample_user}}
    end

    test "credentials", %{conn: conn} do
      assert Steam.credentials(conn) == %Ueberauth.Auth.Credentials{}
    end
  end

  test "connection is cleaned up" do
    conn = %{conn(:get, "http://example.com/path/callback") | private: %{steam_user: @sample_user}}
    conn = conn |> Steam.handle_callback! |> Steam.handle_cleanup!
    assert %{steam_user: nil} = conn.private
  end
end
