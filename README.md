# IP Access Control Plug

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Coveralls][shield-coveralls]

- code :: <https://github.com/KineticCafe/ip_access_control>
- issues :: <https://github.com/KineticCafe/ip_access_control/issues>

IpAccessControl is a [`Plug`][plug] restricts requests so that they must come
from the range of IP addresses specified in the pipeline configuration. This
assumes that the IP is present in the `remote_ip` attribute on the passed-in
`Plug.Conn`.

If the request IP is not allowed, the specified response code and body will be
added to the Plug.Conn and the chain will be halted. Otherwise, the plug chain
will continue.

Documentation can be found at <https://hexdocs.pm/ip_access_control>.

## Installation

Add `ip_access_control` to your list of dependencies in `mix.exs`. If your
application is running behind a proxy, you should to also include and use
[`remote_ip`][remote_ip] as an explicit dependency and configure that as well.

```elixir
def deps do
  [
    {:ip_access_control, "~> 1.1.0"},
    {:remote_ip, "~> 1.0"} # Required if behind a proxy
  ]
end
```

IpAccessControl documentation is found on [HexDocs][docs].

## Semantic Versioning

IpAccessControl follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/ip_access_control
[hexpm]: https://hex.pm/packages/ip_access_control
[licence]: https://github.com/KineticCafe/ip_access_control/blob/main/LICENCE.md
[mdex]: https://hex.pm/packages/mdex
[plug]: https://hexdocs.om/plug/
[remote_ip]: https://hexdocs.pm/remote_ip/
[semver]: https://semver.org/
[shield-coveralls]: https://img.shields.io/coverallsCoverage/github/KineticCafe/ip_access_control?style=for-the-badge
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/ip_access_control?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/ip_access_control?style=for-the-badge&label=licence "MIT"
