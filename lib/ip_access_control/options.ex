defmodule IpAccessControl.Options do
  @moduledoc "Manage IpAccessControl options"

  @on_blocked {IpAccessControl, :ip_access_on_blocked}
  @response_code_on_blocked 401
  @response_body_on_blocked "Not Authenticated"

  @type input_config :: [
          module: module,
          allow: (-> [binary(), ...]) | [binary(), ...],
          on_blocked: (Plug.Conn.t(), Plug.opts() -> Plug.Conn.t()) | module,
          response_code_on_blocked: integer(),
          response_body_on_blocked: String.t()
        ]

  @type config :: %{
          allow: (-> [binary(), ...]) | [binary(), ...],
          on_blocked: (Plug.Conn.t(), Plug.opts() -> Plug.Conn.t()),
          response_code_on_blocked: integer(),
          response_body_on_blocked: String.t()
        }

  @doc "The default value for the given option."
  @spec default(:on_blocked | :response_code_on_blocked | :response_body_on_blocked) ::
          {IpAccessControl, :ip_access_on_blocked}
          | 401
          | String.t()

  def default(option)

  def default(:on_blocked), do: @on_blocked

  def default(:response_code_on_blocked), do: @response_code_on_blocked

  def default(:response_body_on_blocked), do: @response_body_on_blocked

  @doc """
  Pre-processes keyword options. Where possible, function resolution will be
  delayed until `unpack/1` is called.
  """
  @spec pack(input_config()) :: config()
  def pack(options) do
    options = pack(options, :module)

    %{
      allow: pack(options, :allow),
      on_blocked: pack(options, :on_blocked),
      response_code_on_blocked: pack(options, :response_code_on_blocked),
      response_body_on_blocked: pack(options, :response_body_on_blocked)
    }
  end

  @doc "Evaluate preprocessed options."
  @spec unpack(config()) :: config()
  def unpack(options) do
    %{
      allow: unpack(options, :allow),
      on_blocked: unpack(options, :on_blocked),
      response_code_on_blocked: unpack(options, :response_code_on_blocked),
      response_body_on_blocked: unpack(options, :response_body_on_blocked)
    }
  end

  defp pack(options, :module) do
    case Keyword.get(options, :module) do
      nil ->
        options

      module when is_atom(module) ->
        Code.ensure_loaded!(module)

        options =
          if function_exported?(module, :ip_access_allow_list, 0) do
            Keyword.put(options, :allow, {module, :ip_access_allow_list})
          else
            options
          end

        cond do
          function_exported?(module, :ip_access_on_blocked, 2) ->
            Keyword.put(options, :on_blocked, {module, :ip_access_on_blocked})

          function_exported?(module, :call, 2) ->
            Keyword.put(options, :on_blocked, {module, :call})

          true ->
            options
        end
    end
  end

  defp pack(options, :allow) do
    case Keyword.fetch!(options, :allow) do
      {m, f, a} -> {m, f, a}
      {m, f} -> Function.capture(m, f, 0)
      fun when is_function(fun, 0) -> fun
      value -> evaluate(:allow, value)
    end
  end

  defp pack(options, :on_blocked = option) do
    case Keyword.get(options, option, default(option)) do
      plug when is_atom(plug) -> fn conn, options -> plug.call(conn, plug.init(options)) end
      {m, f} -> Function.capture(m, f, 2)
      fun when is_function(fun, 2) -> fun
    end
  end

  defp pack(options, option) do
    evaluate(option, Keyword.get(options, option, default(option)))
  end

  defp unpack(options, :allow = option) do
    case Map.fetch!(options, option) do
      fun when is_function(fun, 0) -> evaluate(option, fun.())
      {m, f, a} -> evaluate(option, apply(m, f, a))
      value -> value
    end
  end

  defp unpack(options, option), do: Map.fetch!(options, option)

  defp evaluate(:allow, allow_list) do
    allow_list
    |> IpAccessControl.parse_allow_list()
    |> BitwiseIp.Blocks.optimize()
  end

  defp evaluate(_option, value), do: value
end
