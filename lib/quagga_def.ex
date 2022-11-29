defmodule QuaggaDef do
  import Bitwise

  @moduledoc """
  Helper functions related to participating in the `Quagga` bamboo clump

  By codifying conventions used therein, it is hope that it will be easier
  to maintain client-facing applications.

  The `Quagga` clump uses a one byte `facet_id` to permit log-type consolidation 
  for a logging identity. This is represented in the high 8-bits of the `log_id`

  The lower 56-bits represent the `base_log_id`.  Such conventions as exist for
  `base_log_id` contents are exposed in the `log_defs`
  """

  @typedoc """
  An 8-bit integer representing the facet of an identity in a `log_id`
  """
  @type facet_id :: integer
  @typedoc """
  A 56-bit integer representing base_log in a `log_id`
  """
  @type base_log_id :: integer
  @typedoc """
  A 64-bit integer representing a complete `log_id`
  """
  @type log_id :: integer
  @typedoc """
  A map representing the Quagga conventions for log entry contents
  """
  @type log_def :: map

  @base_log_bits 56
  @base_logs_end :math.pow(2, @base_log_bits) |> trunc |> then(fn n -> n - 1 end)
  @log_to_def %{
    0 => %{encoding: :raw, type: "text/plain", name: :test},
    53 => %{encoding: :cbor, type: :map, name: :alias},
    101 => %{encoding: :cbor, type: :map, name: :react},
    533 => %{encoding: :cbor, type: :map, name: :reply},
    749 => %{encoding: :cbor, type: :map, name: :tag},
    1337 => %{encoding: :cbor, type: :map, name: :graph},
    8483 => %{encoding: :cbor, type: :map, name: :oasis},
    360_360 => %{encoding: :cbor, type: :map, name: :journal}
  }

  @name_to_log @log_to_def |> Enum.reduce(%{}, fn {l, %{name: n}}, a -> Map.put(a, n, l) end)
  @encoding_to_logs @log_to_def
                    |> Enum.reduce(%{}, fn {l, %{encoding: e}}, a ->
                      Map.update(a, e, [l], fn x -> [l | x] end)
                    end)

  @doc """
  Unpack a given integer log_id into a tuple with
  `{base_log_id, facet_id}`
  """
  @spec log_id_unpack(log_id) :: {base_log_id, facet_id} | :error
  def log_id_unpack(n) when is_integer(n) do
    <<facet_id::integer-size(8), base_log::integer-size(@base_log_bits)>> =
      <<n::integer-size(64)>>

    {base_log, facet_id}
  end

  def log_id_unpack(_), do: :error

  @doc """
  A map of all presently defined log types
  """
  @spec log_defs :: %{base_log_id => log_def}
  def log_defs, do: @log_to_def

  @doc """
  The log definition map for a given integer log_id
  """
  @spec log_def(log_id) :: log_def | :error
  def log_def(n) when is_integer(n) do
    {base_log, _} = log_id_unpack(n)
    Map.get(@log_to_def, base_log, %{})
  end

  def log_def(_), do: :error

  @doc """
  The `base_log_id` for a provided atomic name or integer `log_id`
  """
  @spec base_log(atom | log_id) :: base_log_id | :error
  def base_log(n) when is_atom(n), do: Map.get(@name_to_log, n, :error)

  def base_log(n) when is_integer(n) do
    {base_log, _} = log_id_unpack(n)
    base_log
  end

  def base_log(_), do: :error

  @doc """
  A `log_id` list for a provided atomic name
  Includes the computed values for each possible `facet_id`
  """
  @spec logs_for_name(atom) :: [log_id]
  def logs_for_name(n) do
    @name_to_log
    |> Map.get(n)
    |> samebase_logs
  end

  @doc """
  A `log_id` list for a provided atomic encoding across every `facet_id`
  """
  @spec logs_for_encoding(atom) :: [log_id]
  def logs_for_encoding(e) do
    @encoding_to_logs
    |> Map.get(e, [])
    |> Enum.reduce([], fn bl, a -> [samebase_logs(bl) | a] end)
    |> List.flatten()
  end

  @doc """
  Computes the correct `log_id` given a `base_log_id` or atomic name
  and a `facet_id`
  """
  @spec facet_log(base_log_id | atom, facet_id) :: log_id | :error
  def facet_log(name, facet_id) when is_atom(name) do
    case base_log(name) do
      :error -> :error
      base -> facet_log(base, facet_id)
    end
  end

  def facet_log(base_log, facet_id)
      when base_log <= @base_logs_end and facet_id <= 255 and facet_id >= 0 do
    base_log ||| facet_id <<< 56
  end

  def facet_log(_, _), do: :error

  for base_log <- Map.keys(@log_to_def) do
    matches = Enum.reduce(1..255, [base_log], fn i, a -> [base_log ||| i <<< 56 | a] end)
    defp samebase_logs(n) when n in unquote(matches), do: unquote(matches)
  end

  defp samebase_logs(_), do: []
end
