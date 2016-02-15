defmodule Openmaize.Signup do
  @moduledoc """
  Module to help create a user that can be authenticated using Openmaize.

  ## User model

  The example schema below is the most basic setup for Openmaize
  (:name and :password_hash are configurable):

      schema "users" do
        field :name, :string
        field :role, :string
        field :password, :string, virtual: true
        field :password_hash, :string

        timestamps
      end

  In the example above, the `:name` is used to identify the user. This can
  be set to any other value, such as `:email`. See the documentation for
  Openmaize.Login for details about logging in with a different value.

  See the documentation for Openmaize.Config for details about configuring
  the `:password_hash` value.

  The `:role` is needed for authorization, and the `:password` and the
  `:password_hash` fields are needed for the `create_user` function
  in this module (see the documentation for Openmaize.Config for information
  about changing :password_hash to some other value). Note the addition
  of `virtual: true` to the definition of the password field. This means
  that it will not be stored in the database.

  """

  import Ecto.Changeset
  alias Openmaize.Config

  @doc """
  Hash a password and add the hash to the database.

  Comeonin.Bcrypt is the default hashing function, but this can be changed to
  Comeonin.Pbkdf2 by setting the Config.get_crypto_mod value to :pbkdf2.

  ## Options

  The following options are available:

  * min_length - the minimum length of the password (default is 8 characters)
  * max_length - the maximum length of the password (default is 80 characters)

  ## Examples

  The following example first checks that the password is at least 12 characters
  long before hashing it:

      changeset
      |> Openmaize.Signup.create_user(params, [min_length: 12])

  """
  def create_user(changeset, params, opts \\ []) do
    {min_len, max_len} = {Keyword.get(opts, :min_length, 8), Keyword.get(opts, :max_length, 80)}
    changeset
    |> cast(params, ~w(password), [])
    |> validate_length(:password, min: min_len, max: max_len)
    |> put_pass_hash
  end

  @doc """
  Add a confirmation token to the user changeset.

  Add the following three entries to your user schema:

      field :confirmation_token, :string
      field :confirmation_sent_at, Ecto.DateTime
      field :confirmed_at, Ecto.DateTime

  ## Examples

  In the following example, the `add_confirm_token` function is called with
  a key generated by `gen_token_link`:

      changeset
      |> Openmaize.Signup.add_confirm_token(key)

  """
  def add_confirm_token(changeset, key) do
    changeset
    |> put_change(:confirmation_token, key)
    |> put_change(:confirmation_sent_at, Ecto.DateTime.utc)
  end

  @doc """
  Add a reset token to the user changeset.

  Add the following two entries to your user schema:

  field :reset_token, :string
  field :reset_sent_at, Ecto.DateTime

  As with `add_confirm_token`, the function `gen_token_link` can be used
  to generate the token and link.
  """
  def add_reset_token(changeset, key) do
    changeset
    |> put_change(:reset_token, key)
    |> put_change(:reset_sent_at, Ecto.DateTime.utc)
  end

  @doc """
  Add the password hash for the new password to the database.

  If the update is successful, the reset_token and reset_sent_at
  values will be set to nil.
  """
  def reset_password(user, password) do
    Config.repo.transaction(fn ->
      user = change(user, %{Config.hash_name => Config.get_crypto_mod.hashpwsalt(password)})
      |> Config.repo.update!

      change(user, %{reset_token: nil, reset_sent_at: nil})
      |> Config.repo.update!
    end)
  end

  @doc """
  Generate a confirmation token and a link containing the email address
  and the token.

  The link is used to create the url that the user needs to follow to
  confirm the email address.

  The user_id is the actual name or email address of the user, and
  unique_id refers to the type of identifier. For example, if you
  want to use `username=fred` in your link, you need to set the
  unique_id to :username. The default unique_id is :email.
  """
  def gen_token_link(user_id, unique_id \\ :email) do
    key = :crypto.strong_rand_bytes(24) |> Base.url_encode64
    {key, "#{unique_id}=#{URI.encode_www_form(user_id)}&key=#{key}"}
  end

  defp put_pass_hash(%Ecto.Changeset{valid?: true,
                     changes: %{password: password}} = changeset) do
    put_change(changeset, Config.hash_name, Config.get_crypto_mod.hashpwsalt(password))
  end
  defp put_pass_hash(changeset), do: changeset
end
