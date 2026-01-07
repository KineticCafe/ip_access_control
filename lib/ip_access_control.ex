defmodule IpAccessControl do
  @moduledoc """
  This Plug restricts requests so that they must come from the range of IP addresses
  specified in the pipeline config. A request's IP address is deemed to be present as
  `%Plug.Conn{remote_ip: _}`.

  If the request IP is not allowed, the specified response code and body will be added to
  the Plug.Conn and the chain will be halted. Otherwise, the plug chain will continue.

  Include this module in your plug chain with its configuration.

  ## Configuration

  - `:allow`: the list of permitted IP addresses or CIDR ranges, which may be configured
    as a static list or as a function returning the list of IP addresses or CIDR ranges

  - `:on_blocked`: a Plug to call when the remote IP address is not allowed; it will be
    passed the options provided to the IpAccessControl plug. A default handler is called
    if not provided.

  - `:response_code_on_blocked`: The HTTP status code assigned to the response when the
    request's IP address is not allowed. Used by the default `on_blocked` handler, but may
    be used by an alternative `:on_blocked` plug. Defaults to `401` if not specified.

  - `:response_body_on_blocked`: The body assigned to the response when the request's IP
    address is not allowed. Used by the default `on_blocked`, but may be used by an
    alternative `on_blocked` plug. Defaults to `"Not Authenticated"` if not specified.

  - `:module`: A shorthand configuration for specifying an access module which implements
    at least one of `ip_access_allow_list/0` (the `:allow` function),
    `ip_access_on_blocked/2` (the preferred `:on_blocked` function), or `call/2` (an
    `:on_blocked` plug function).

    This option is only used during the `Plug.init/1` callback and is resolved to the
    above options.

  ### Allow List Configuration

  The list of permitted IP addresses or CIDR ranges may be specified using _either_ the
  `module` option described below _or_ the `allow` parameter. Each item in the allow list
  must be tested in turn, so a smaller list will outperform a larger list.

  The `allow` parameter must be one of the following:

  - a list of IP addresses or CIDR ranges
  - a 0-arity function that returns a list of IP addresses or CIDR ranges
  - a `{module, function}` tuple to a 0-arity function that returns a list of IP addresses
    or CIDR ranges,
  - a `t:mfa/0` tuple

  Formats supported include:

  - IPv4 string format;
  - IPv6 string format;
  - CIDRv4 string format; or
  - CIDRv6 string format.

  Examples:

  ```elixir
  # Include after a plug which puts the request IP to the remote_ip
  # attribute on the Plug.Conn.
  plug IpAccessControl, allow: ["1.1.1.0/31", "1.1.0.0/24", "127.0.0.0/8"]

  def allow, do: ["1.1.1.0/31", "1.1.0.0/24", "127.0.0.0/8"]

  plug IpAccessControl, allow: &__MODULE__.allow/0

  plug IpAccessControl, allow: {__MODULE__, :allow}

  plug IpAccessControl, allow: {__MODULE__, :allow, []}
  ```

  ### Blocked Action Configuration

  The action to take when the remote IP address is not allowed may be specified using the
  `module` option described below or the `on_blocked` option. If not specified, a default
  `on_blocked` implementation will be provided that uses `response_code_on_blocked` and
  `response_body_on_blocked`.

  When the remote IP address is blocked, the Plug pipeline is halted.

  - `on_blocked`: A Plug that will be called when the IP address is not allowed. It will
    be passed the options provided to the the IpAccessControl plug.
  - `response_code_on_blocked`: The HTTP status code assigned to the response when the
    request's IP address is not allowed. Defaults to `401` if not specified.
  - `response_body_on_blocked`: The body assigned to the response when the request's IP
    address is not allowed. Defaults to `"Not Authenticated"` if
    not specified.

  Example:

  ```elixir
  def on_blocked(conn, opts) do
    Conn.send_resp(
      conn,
      options[:response_code_on_blocked],
      String.reverse(options[:response_body_on_blocked])
    )
  end

  plug IpAccessControl,
    allow: ["1.1.1.0/31", "1.1.0.0/24", "127.0.0.0/8"],
    on_blocked: &__MODULE__.on_blocked/2
  ```

  ### Module Configuration

  A single configuration option can be provided as `module` that refers to a module that
  implements one or both of the functions `ip_access_allow_list/0` (this is a function
  that will be used for `allow`) and `ip_access_on_blocked/2` (this is a Plug function
  used for `on_blocked`).

  If provided, the configurations available through `module` will take priority over
  functions or values specified in `allow` or `on_blocked`.

  The IpAccessControl can be configured with any of the following options.

  Example:

  ```elixir
  plug IpAccessControl, module: EmployeeAccess
  ```

  ## Security Note

  Adam Pritchard wrote an extensive post on the perils of discovering the
  ["real" client IP][xff]. Because this module is intended for security, you _should_ be
  behind a proxy that you control or trust and reading the rightmost IP in the derived
  remote IP address list.

  The key points he makes are:

  > - When deriving the "real client IP address" from the `X-Forwarded-For` header, use
  >   the rightmost IP in the list.
  > - The leftmost IP in the XFF header is commonly considered to be "closest to the
  >   client" and "most real", but it's trivially spoofable. Don't use it for anything
  >   even close to security-related.
  > - When choosing the rightmost XFF IP, make sure to use the last instance of that
  >   header.
  > - Using special "true client IPs" set by reverse proxies (like `X-Real-IP`,
  >   `True-Client-IP`, etc.) can be good, but it depends on a) how the reverse proxy
  >   actually sets it, b) whether the reverse proxy sets it if it's already
  >   present/spoofed, and c) how you've configured the reverse proxy (sometimes).
  > - Any header not specifically set by your reverse proxy cannot be trusted. For
  >   example, you must not check the `X-Real-IP` header if you're not behind Nginx or
  >   something else that always sets it, because you'll be reading a spoofed value.
  > - A lot of rate limiter implementations are using spoofable IPs and are vulnerable to
  >   rate limiter escape and memory exhaustion attacks.
  >
  > _If you use the "real client IP" anywhere in your code or infrastructure, you need to
  > go check right now how you're deriving it._

  The authors of IpAccessControl have used the [`remote_ip`][remote_ip] plug for resolving
  IP addresses from proxy headers successfully in the past, but the configuration of that
  or a similar plug is entirely outside of the purview of this library.

  [remote_ip]: https://hexdocs.pm/remote_ip/
  [xff]: https://adam-p.ca/blog/2022/03/x-forwarded-for/
  """

  @behaviour Plug

  alias Plug.Conn

  @typep ip_block_list :: BitwiseIp.Blocks.t()

  @spec init(IpAccessControl.Options.input_config()) :: IpAccessControl.Options.config()
  def init(options), do: IpAccessControl.Options.pack(options)

  @spec call(Conn.t(), IpAccessControl.Options.config()) :: Conn.t()
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

  @spec ip_access_on_blocked(Conn.t(), IpAccessControl.Options.config()) :: Conn.t()
  def ip_access_on_blocked(conn, options),
    do: Conn.send_resp(conn, options[:response_code_on_blocked], options[:response_body_on_blocked])

  @doc """
  Returns `true` if the remote IP is in the given allow list. The remote IP address can be
  provided either as a Plug.Conn.t(), an IP address tuple, or an IP address string.

  If the remote IP is provided as a Plug.Conn.t(), the remote IP will be pulled from the
  Plug.Conn.t()'s `remote_ip`. If the remote IP is provided as a string, this function
  will return `false` if the IP address cannot be parsed.

  If neither the `remote_ip` nor allow list are provided, always returns `false`.
  """
  @spec allowed?(
          Conn.t() | binary() | :inet.ip_address() | nil | BitwiseIp.t(),
          [binary(), ...] | (-> [binary(), ...]) | ip_block_list() | nil
        ) ::
          boolean
  def allowed?(_, []), do: false
  def allowed?(_, nil), do: false
  def allowed?(nil, _), do: false
  def allowed?("", _), do: false

  def allowed?(remote_ip, allow_fn) when is_function(allow_fn, 0), do: allowed?(remote_ip, allow_fn.())

  def allowed?(%Conn{remote_ip: remote_ip}, allow_list), do: allowed?(remote_ip, allow_list)

  def allowed?(remote_ip, allow_list) when is_binary(remote_ip) do
    case BitwiseIp.parse(remote_ip) do
      {:ok, remote_ip} -> allowed?(remote_ip, allow_list)
      _ -> false
    end
  end

  def allowed?(remote_ip, allow_list) when is_tuple(remote_ip), do: allowed?(BitwiseIp.encode(remote_ip), allow_list)

  def allowed?(%BitwiseIp{} = remote_ip, allow_list),
    do: BitwiseIp.Blocks.member?(parse_allow_list(allow_list), remote_ip)

  def allowed?(_, _), do: false

  @doc false
  def parse_allow_list(list) do
    Enum.map(list, fn item ->
      case item do
        %BitwiseIp.Block{} -> item
        _ -> BitwiseIp.Block.parse!(item)
      end
    end)
  end
end
