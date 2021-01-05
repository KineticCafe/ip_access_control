defmodule IPAccessControlPlug do
  @moduledoc """
  This plug restricts requests so that they must come from the range of IP
  addresses specified in the pipeline config. This assumes that the IP is
  present in the `remote_ip` attribute on the passed-in Plug.

  If the request IP is not allowed, the specified response code and body will
  be added to the Plug.Conn and the chain will be halted. Otherwise, the plug
  chain will continue.

  Include this module in your plug chain with the required options.

  Options:

  - `module`: A module that implements one or both of `ip_access_allow_list/0`
    (provides a function for `allow`) and `ip_access_on_blocked/2` (provides
    a function plug for `on_blocked`).
  - `allow`: A list of IP ranges specified as CIDR range strings, such as
    `["1.1.1.0/31", "1.1.0.0/24"]`. This designates the ranges of IP
    addresses which are allowed. This _may_ be provided as a string
    containing a comma-separated list of CIDR range strings (e.g.,
    `"1.1.1.0/31,1.1.0.0/24"`). May be provided as a function that returns
    such a list.
  - `on_blocked`: A Plug (function or module) that will be called when the IP
    address is not in the allow list. It will be passed the options provided
    to the the IPAccessControl plug. After the plug is called, the plug
    pipeline is halted.
  - `response_code_on_blocked`: The HTTP status code assigned to the response
    when the request’s IP address is not allowed. Defaults to `401` if not
    specified.
  - `response_body_on_blocked`: The body assigned to the response when the
    request's IP address is not allowed. Defaults to `"Not Authenticated"` if
    not specified.

  Example:

      # Include after a plug which adds the request IP to the remote_ip
      # attribute on the Plug.Conn.
      plug IPAccessControlPlug,
        allow: ["1.1.1.0/31", "1.1.0.0/24", "127.0.0.0/8"]

  ## Installation

  Add `ip_access_control_plug` to your dependencies. If your application is
  running behind a proxy, you will probably need to also include `remote_ip`
  as a dependency.

      def deps do
        {:ip_access_control_plug, "~> 1.0.0"},
        {:remote_ip, "~> 0.1"} # Optional
      end
  """

  alias Plug.Conn

  @type ipv4_address :: :inet.ip4_address()
  @type ipv6_address :: :inet.ip6_address()

  @type cidr_mask ::
          {ipv4_address(), ipv4_address(), 0..32} | {ipv6_address(), ipv6_address(), 0..128}
  @type cidr_mask_list :: [cidr_mask, ...]

  @typedoc """
  A callback function that returns either a CIDR mask list, a list of
  binaries, or a single binary string. This defers allow parsing until
  this plug is called.
  """
  @type cidr_mask_list_fn :: (() -> cidr_mask_list() | [binary(), ...] | binary())

  @typedoc """
  A plug function or module that will be called if the IP address in question
  is not allowed.
  """
  @type on_blocked_fn :: (Plug.Conn.t(), Plug.opts() -> Plug.Conn.t()) | module

  @type input_config :: [
          module: module,
          allow: [binary(), ...] | binary() | cidr_mask_list_fn(),
          on_blocked: on_blocked_fn,
          response_code_on_blocked: integer(),
          response_body_on_blocked: String.t()
        ]

  @type config :: [
          allow: cidr_mask_list() | cidr_mask_list_fn(),
          on_blocked: on_blocked_fn,
          response_code_on_blocked: integer(),
          response_body_on_blocked: String.t()
        ]

  @doc "Initialize the plug with options."
  @spec init(input_config) :: config
  def init(options) do
    allow_list =
      options
      |> Keyword.fetch!(:allow)
      |> parse_allow_list()

    default_on_blocked = &__MODULE__.ip_access_on_blocked/2

    on_blocked =
      case Keyword.get(options, :on_blocked) do
        plug when is_atom(plug) and not is_nil(plug) ->
          if function_exported?(plug, :call, 2) and function_exported?(plug, :init, 1) do
            fn conn, options -> plug.call(conn, plug.init(options)) end
          else
            default_on_blocked
          end

        plug when is_function(plug, 2) ->
          plug

        _ ->
          default_on_blocked
      end

    options
    |> Keyword.put(:allow, allow_list)
    |> Keyword.put(:on_blocked, on_blocked)
    |> Keyword.put_new(:response_code_on_blocked, 401)
    |> Keyword.put_new(:response_body_on_blocked, "Not Authenticated")
  end

  # sobelow_skip ["XSS.SendResp"]
  @spec call(Plug.Conn.t(), config) :: Plug.Conn.t()
  def call(conn, options) do
    allow_list = Keyword.fetch!(options, :allow)
    # Do any of the allowed IP ranges contain the request ip?
    if allowed?(conn, allow_list) do
      # If the request IP was in the range, return the conn unchanged to
      # continue through the plug pipeline
      conn
    else
      # If the request IP was not in the range, return the specified response
      # code and response body
      options
      |> Keyword.get(:on_blocked)
      |> apply([conn, options])
      |> Conn.halt()
    end
  end

  def ip_access_on_blocked(conn, options) do
    Conn.send_resp(
      conn,
      Keyword.get(options, :response_code_on_blocked),
      Keyword.get(options, :response_body_on_blocked)
    )
  end

  @doc """
  Returns `true` if the remote IP is in the given allow list. The remote IP
  address can be provided either as a Plug.Conn.t(), an IP address tuple, or
  an IP address string.

  If the remote IP is provided as a Plug.Conn.t(), the remote IP will be
  pulled from the Plug.Conn.t()'s `remote_ip`. If the remote IP is provided
  as a string, this function will return `false` if the IP address cannot be
  parsed.

  If neither the remote_ip nor allow list are provided, always returns
  `false`.
  """
  @spec allowed?(
          Plug.Conn.t() | binary() | :inet.ip_address() | nil,
          cidr_mask_list() | [] | nil | cidr_mask_list_fn()
        ) ::
          boolean
  def allowed?(_, []), do: false

  def allowed?(_, nil), do: false

  def allowed?(nil, _), do: false

  def allowed?("", _), do: false

  def allowed?(remote_ip, allow_fn) when is_function(allow_fn, 0) do
    allowed?(remote_ip, parse_allow_list(allow_fn.()))
  end

  def allowed?(%Plug.Conn{remote_ip: remote_ip}, allow_list) do
    allowed?(remote_ip, allow_list)
  end

  def allowed?(remote_ip, allow_list) when is_binary(remote_ip) do
    case :inet.parse_address(String.to_charlist(remote_ip)) do
      {:ok, remote_ip} -> allowed?(remote_ip, allow_list)
      _ -> false
    end
  end

  def allowed?(remote_ip, allow_list) when is_tuple(remote_ip) do
    Enum.any?(allow_list, &InetCidr.contains?(&1, remote_ip))
  end

  def allowed?(_, _), do: false

  @spec parse_allow_list(cidr_mask_list_fn() | [binary(), ...] | binary()) ::
          cidr_mask_list() | cidr_mask_list_fn()
  defp parse_allow_list(allow_list)

  defp parse_allow_list(allow_fn) when is_function(allow_fn, 0) do
    allow_fn
  end

  defp parse_allow_list(allow_list) when is_list(allow_list) do
    allow_list
    |> Enum.map(fn
      tuple when is_tuple(tuple) -> tuple
      string when is_binary(string) -> parse_allow_list(string)
    end)
    |> List.flatten()
  end

  defp parse_allow_list(allow_list) when is_binary(allow_list) do
    allow_list
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&InetCidr.parse/1)
  end
end
