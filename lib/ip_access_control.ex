defmodule IpAccessControl do
  @behaviour Plug

  @moduledoc """
  This Plug restricts requests so that they must come from the range of IP
  addresses specified in the pipeline config. A request's IP address is deemed
  to be present as `%Plug.Conn{remote_ip: _}`.

  If the request IP is not allowed, the specified response code and body will
  be added to the Plug.Conn and the chain will be halted. Otherwise, the plug
  chain will continue.

  Include this module in your plug chain with its configuration.

  ## Configuration

  There are two main configuration options:

  - the allow list of IP addresses or CIDR ranges, which may be configured as
    a static list or as a function returning the list of IP addresses or CIDR
    ranges; and

  - a Plug (either module or function) to call when the remote IP address is not
    allowed.

  Note that each item in the allow list must be tested in turn, so a smaller
  list will outperform a larger list. Future versions of this Plug may include
  a way of caching results.

  ### Allow List Configuration

  The list of permitted IP addresses or CIDR ranges may be specified using
  _either_ the `module` option described below _or_ the `allow` parameter.

  The `allow` parameter must be one of the following:

  - a list of IP addresses or CIDR ranges, or
  - a 0-arity function that returns a list of IP addresses or CIDR ranges, or
  - a `{module, function}` tuple to a 0-arity function that returns a list of IP
    addresses or CIDR ranges.

  Formats supported include:

  - IPv4 string format;
  - IPv6 string format;
  - CIDRv4 string format; or
  - CIDRv6 string format.

  Examples:

      # Include after a plug which puts the request IP to the remote_ip
      # attribute on the Plug.Conn.
      plug IPAccessControl,
        allow: ["1.1.1.0/31", "1.1.0.0/24", "127.0.0.0/8"]

      plug IPAccessControl,
        allow: fn -> ["1.1.1.0/31", "1.1.0.0/24", "127.0.0.0/8"] end

  ### Blocked Action Configuration

  The action to take when the remote IP address is not allowed may be specified
  using the `module` option described below or the `on_blocked` option. If not
  specified, a default `on_blocked` implementation will be provided that uses
  `response_code_on_blocked` and `response_body_on_blocked`.

  When the remote IP address is blocked, the Plug pipeline is halted.

  - `on_blocked`: A Plug that will be called when the IP address is not allowed.
    It will be passed the options provided to the the IPAccessControl plug.
  - `response_code_on_blocked`: The HTTP status code assigned to the response
    when the request’s IP address is not allowed. Defaults to `401` if not
    specified.
  - `response_body_on_blocked`: The body assigned to the response when the
    request's IP address is not allowed. Defaults to `"Not Authenticated"` if
    not specified.

  Example:

      plug IPAccessControl,
        allow: ["1.1.1.0/31", "1.1.0.0/24", "127.0.0.0/8"],
        on_blocked: fn conn, opts ->
          Conn.send_resp(
            conn,
            options[:response_code_on_blocked],
            String.reverse(options[:response_body_on_blocked])
          )
        end

  ### Module Configuration

  A single configuration option can be provided as `module` that refers to
  a module that implements one or both of the functions `ip_access_allow_list/0`
  (this is a function that will be used for `allow`) and
  `ip_access_on_blocked/2` (this is a Plug function used for `on_blocked`).

  If provided, the configurations available through `module` will take priority
  over functions or values specified in `allow` or `on_blocked`.

  The IpAccessControl can be configured with any of the following options.

  Example:

      plug IPAccessControl, module: EmployeeAccess

  ## Installation

  Add `ip_access_control` to your dependencies. If your application is
  running behind a proxy, you will probably need to also include `remote_ip`
  as a dependency.

      def deps do
        {:ip_access_control, "~> 1.0"},
        {:remote_ip, "~> 1.0"} # Optional
      end
  """

  alias Plug.Conn

  @typep ip_block_list :: [%RemoteIp.Block{}, ...]

  @doc "Initialize the plug with options."
  @spec init(keyword) :: keyword
  def init(options) do
    IpAccessControl.Options.pack(options)
  end

  @spec call(Plug.Conn.t(), keyword) :: Plug.Conn.t()
  def call(conn, options) do
    options = IpAccessControl.Options.unpack(options)

    if allowed?(conn, options[:allow]) do
      conn
    else
      options[:on_blocked]
      |> apply([conn, options])
      |> Conn.halt()
    end
  end

  def ip_access_on_blocked(conn, options) do
    Conn.send_resp(conn, options[:response_code_on_blocked], options[:response_body_on_blocked])
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
          [binary(), ...] | (() -> [binary(), ...]) | ip_block_list() | nil
        ) ::
          boolean
  def allowed?(_, []) do
    false
  end

  def allowed?(_, nil) do
    false
  end

  def allowed?(nil, _) do
    false
  end

  def allowed?("", _) do
    false
  end

  def allowed?(remote_ip, allow_fn) when is_function(allow_fn, 0) do
    allowed?(remote_ip, allow_fn.())
  end

  def allowed?(%Plug.Conn{remote_ip: remote_ip}, allow_list) do
    allowed?(remote_ip, allow_list)
  end

  def allowed?(remote_ip, allow_list) when is_binary(remote_ip) do
    case :inet.parse_strict_address(to_charlist(remote_ip)) do
      {:ok, remote_ip} -> allowed?(remote_ip, allow_list)
      _ -> false
    end
  end

  def allowed?(remote_ip, allow_list) when is_tuple(remote_ip) do
    allow_list
    |> parse_allow_list()
    |> Enum.any?(&RemoteIp.Block.contains?(&1, RemoteIp.Block.encode(remote_ip)))
  end

  def allowed?(_, _) do
    false
  end

  @doc false
  def parse_allow_list(list) do
    Enum.map(list, fn item ->
      case item do
        %RemoteIp.Block{} -> item
        _ -> RemoteIp.Block.parse!(item)
      end
    end)
  end
end
