defmodule Ueberauth.Strategy.Steam.OpenID do
  @url_namespace "http://specs.openid.net/auth/2.0"
  @url_login "https://steamcommunity.com/openid/login"
  
  def checkid_setup_url(callback_url) do
    query = checkid_setup_query(callback_url, callback_url)
    @url_login <> "?" <> URI.encode_query(query)
  end
  
  defp checkid_setup_query(realm, return_to) do
    %{
      "openid.mode" => "checkid_setup",
      "openid.realm" => realm,
      "openid.return_to" => return_to,
      "openid.ns" => @url_namespace,
      "openid.claimed_id" => @url_namespace <> "/identifier_select",
      "openid.identity" => @url_namespace <> "/identifier_select",
    }
  end

  def check_authentication(params) do
    check_params = Map.put(params, "openid.mode", "check_authentication")
    case HTTPoison.get(@url_login, [], params: check_params) do
      {:ok, %{status_code: 200, body: "ns:" <> @url_namespace <> "\nis_valid:true\n"}} ->
        {:ok, params}
      _ ->
        {:error, :invalid_request}
    end
  end

  def get_steam_user_id("http://steamcommunity.com/openid/id/" <> id), do: {:ok, id}
  def get_steam_user_id("https://steamcommunity.com/openid/id/" <> id), do: {:ok, id}
  def get_steam_user_id(_), do: {:error, :badarg}
end
