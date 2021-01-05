defmodule IpAccessControlPlug.MixProject do
  @moduledoc false

  use Mix.Project

  @project_url "https://github.com/KineticCafe/bamboo_elastic_email"
  @version "1.0.0"

  def project do
    [
      app: :ip_access_control_plug,
      version: @version,
      source_url: @project_url,
      homepage_url: @project_url,
      name: "IP Access Control Plug",
      elixir: "~> 1.8",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_apps: [:dialyzer, :elixir, :kernel, :mix, :stdlib],
        ignore_warnings: ".dialyzer_ignore",
        flags: [:unmatched_returns, :error_handling, :underspecs]
      ],
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  # defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Austin Ziegler", "Kinetic Commerce"],
      licenses: ["MIT"],
      links: %{
        "Github" => @project_url
      }
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/ip_access_control_plug",
      main: "IPAccessControlPlug",
      source_url: @project_url,
      extras: ["README.md", "Changelog.md", "Contributing.md", "Licence.md"]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:inet_cidr, "~> 1.0"},
      {:credo, "~> 1.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false},
      ex_doc_dep(Version.compare(System.version(), "1.7.0"))
    ]
  end

  defp ex_doc_dep(:lt), do: {:ex_doc, "~> 0.18.0", only: :dev, runtime: false}
  defp ex_doc_dep(_), do: {:ex_doc, "~> 0.19", only: :dev, runtime: false}
end
