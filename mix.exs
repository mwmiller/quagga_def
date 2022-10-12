defmodule QuaggaDef.MixProject do
  use Mix.Project

  def project do
    [
      app: :quagga_def,
      version: "0.1.0",
      elixir: "~> 1.14",
      name: "QuaggaDef",
      source_url: "https://github.com/mwmiller/quagga_def",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end

  defp description do
    """
    Quagga bamboo clump convention definitions and functions
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Matt Miller"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mwmiller/quagga_def"
      }
    ]
  end
end
