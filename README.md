# IP Access Control Plug

This plug restricts requests so that they must come from the range of IP
addresses specified in the pipeline configuration. This assumes that the IP is
present in the `remote_ip` attribute on the passed-in `Plug.Conn`.

If the request IP is not allowed, the specified response code and body will be
added to the Plug.Conn and the chain will be halted. Otherwise, the plug chain
will continue.

Documentation can be found at
[https://hexdocs.pm/ip_access_control][hexdocs].

## Installation

Add `ip_access_control` to your dependencies. If your application is running
behind a proxy, you should to also include and use [`remote_ip`] as an explicit
dependency and configure that as well.

```elixir
def deps do
  [
    {:ip_access_control, "~> 1.0.0"},
    {:remote_ip, "~> 1.0"} # Required if behind a proxy
  ]
end
```

## Community and Contributing

We welcome your contributions, as described in [Contributing.md][]. Like all
Kinetic Cafe [open source projects][], is under the Kinetic Cafe Open Source
[Code of Conduct][kccoc].

[build status svg]: https://travis-ci.org/KineticCafe/bamboo_elastic_email.svg?branch=master
[build status]: https://travis-ci.org/KineticCafe/bamboo_elastic_email
[contributing.md]: Contributing.md
[open source projects]: https://github.com/KineticCafe
[kccoc]: https://github.com/KineticCafe/code-of-conduct
[hexdocs]: https://hexdocs.pm/ip_access_control
[`remote_ip`]: https://hexdocs.pm/remote_ip/api-reference.html
