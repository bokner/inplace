defmodule Inplace.MixProject do
  use Mix.Project

  def project do
    [
      app: :inplace,
      version: "0.2.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description()
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
      {:replbug, "~> 1.0.2", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

    defp description() do
    "Mutable data structures"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "inplace",
      # These are the default files included in the package
      files: ~w(lib src test mix.exs README* LICENSE*
                ),
      exclude_patterns: ["misc/**", "scripts/**", "**/*._exs", "**/*._ex"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bokner/inplace"}
    ]
  end

end
