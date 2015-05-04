defmodule Openmaize.Tools do
  @moduledoc """
  """

  import Plug.Conn
  alias Openmaize.Config

  def redirect_to_login(conn) do
    uri = "http://" <> conn.host <> Config.login_page
    conn
    |> put_resp_header("location", uri)
    |> put_status(301)
  end

end