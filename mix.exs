defmodule ResourcePool.MixProject do
  use Mix.Project

  def project do
    [
      app: :rsrc_pool_ex,
      version: "1.0.3",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: description(),
      package: package(),
      # Documentation config:
      name: "Resource pool",
      source_url: "https://github.com/alekras/ex.rsrc_pool",
      docs: [
        #logo: "path/to/logo.png",
        extras: ["README.md", "README_1.md"]]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "The goal of ResourcePool (rsrc_pool_ex) Elixir library is reduce the overhead of creating new resources by reusing of the same resources among multiple processes."
  end

  defp package() do
    [
      # These are the default files included in the package
      files: ~w(lib test priv .formatter.exs mix.exs README* readme* LICENSE*
                license* CHANGELOG* changelog* src),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/alekras/ex.rsrc_pool"}
    ]
  end

end
