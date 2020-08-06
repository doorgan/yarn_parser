defmodule YarnParser.MixProject do
  use Mix.Project

  def project do
    [
      app: :yarn_parser,
      version: "0.3.1",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: "A simple yarn.lock parser",
      package: package(),
      deps: deps(),
      source_url: "https://github.com/doorgan/yarn_parser"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 0.6"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/doorgan/yarn_parser"}
    ]
  end
end
