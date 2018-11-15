defmodule Ueberauth.Strategy.Steam.API do
  @url_steam_summaries "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002"

  defp get_steam_api_key do
    {:ok, env} = Application.fetch_env(:ueberauth, Ueberauth.Strategy.Steam)
    {:ok, api_key} = Keyword.fetch(env, :api_key)
    api_key
  end
  
  def get_steam_user(steam_user_id) do
    with \
      params <- %{key: get_steam_api_key(), steamids: steam_user_id},
      {:ok, %{body: body}} <- HTTPoison.get(@url_steam_summaries, [], params: params),
      {:ok, %{"response" => %{"players" => [player|_]}}} <- Poison.decode(body)
    do
      {:ok, player}
    else _ ->
      {:error, :invalid_user}
    end
  end
end
