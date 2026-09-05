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
  # The top byte of the 56-bit base-log space (bits 48..55) is the *family tag*
  # for derived logs (e.g. game logs). It is always non-zero for a derived log,
  # so those can never collide with the hand-allocated IDs in `@log_to_def`,
  # all of which live in the low 48 bits and therefore always carry a zero byte.
  #
  # A zero family byte means the base log is hand-allocated (not reserved).
  # A non-zero family byte tags the derived-log family (e.g. 0x1 = backgammon),
  # so unrelated derived-log families can share the space and indexers can
  # filter by kind.
  @reserved_log_value_bits 48
  @reserved_log_value_mask :math.pow(2, @reserved_log_value_bits)
                           |> trunc
                           |> then(fn n -> n - 1 end)
  # Family tags (bits 48..55) for the derived-log space.
  # Support for a game is what the tag means: a registered game family gets a
  # concrete ruleset, while any other non-zero byte is still a valid derived
  # log family that clients render by its tag.
  @family_backgammon 0x1
  @families [backgammon: @family_backgammon]
  @log_to_def %{
    0 => %{encoding: :raw, type: "text/plain", name: :test},
    53 => %{encoding: :cbor, type: :map, name: :alias},
    101 => %{encoding: :cbor, type: :map, name: :react},
    121 => %{encoding: :cbor, type: :map, name: :mention},
    360 => %{encoding: :cbor, type: :map, name: :about},
    533 => %{encoding: :cbor, type: :map, name: :reply},
    749 => %{encoding: :cbor, type: :map, name: :tag},
    777 => %{encoding: :cbor, type: :map, name: :challenge},
    1337 => %{encoding: :cbor, type: :map, name: :graph},
    7310 => %{encoding: :cbor, type: :map, name: :lexicon},
    8008 => %{encoding: :raw, type: "image/jpeg", name: :jpeg},
    8009 => %{encoding: :raw, type: "image/png", name: :png},
    8010 => %{encoding: :raw, type: "image/gif", name: :gif},
    8483 => %{encoding: :cbor, type: :map, name: :oasis},
    360_360 => %{encoding: :cbor, type: :map, name: :journal}
  }

  @name_to_log @log_to_def |> Enum.reduce(%{}, fn {l, %{name: n}}, a -> Map.put(a, n, l) end)
  @type_to_log @log_to_def
               |> Enum.reduce(%{}, fn
                 {l, %{type: t}}, a when is_binary(t) -> Map.put(a, t, l)
                 _, a -> a
               end)
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
  The `base_log_id` for a provided atomic name, string type or integer `log_id`
  """
  @spec base_log(atom | log_id | binary) :: base_log_id | :error
  def base_log(t) when is_binary(t), do: Map.get(@type_to_log, t, :error)
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

  @doc """
  Whether a given `base_log_id` is a reserved (derived) log.

  Any base log with a non-zero family byte (bits 48..55) is a derived log,
  never a hand-allocated ID (all of which live in the low 48 bits).
  """
  @spec reserved_base_log?(base_log_id | log_id) :: boolean
  def reserved_base_log?(n) when is_integer(n) do
    {base_log, _} = log_id_unpack(n)
    family_byte(base_log) != 0
  end

  def reserved_base_log?(_), do: false

  @doc """
  Fold a hash-derived value into the reserved base-log range for a family.

  `n` is any unsigned integer (e.g. the first 6 bytes of a SHA-256). The low
  48 bits are preserved as the log's identity, and `family` (a value in
  `1..255`) is placed in bits 48..55 as the family tag.

  `family` defaults to the backgammon family tag.

  ## Examples

      iex> QuaggaDef.derived_log_base(0)
      281474976710656

      iex> QuaggaDef.derived_log_base(0, 2)
      562949953421312

      iex> QuaggaDef.family_for_block(QuaggaDef.derived_log_base(0))
      :backgammon

  """
  @spec derived_log_base(pos_integer, 1..255) :: base_log_id
  def derived_log_base(n, family \\ @family_backgammon)

  def derived_log_base(n, family)
      when is_integer(n) and n >= 0 and is_integer(family) and family >= 1 and family <= 255 do
    band(n, @reserved_log_value_mask) ||| family <<< 48
  end

  @doc """
  The family tag (bits 48..55) of a base-log ID, as an atom.

  Returns `:unknown` for hand-allocated (non-reserved) IDs or unrecognized tags.
  """
  @spec family_for_block(base_log_id | log_id) :: atom
  def family_for_block(n) when is_integer(n) do
    {base_log, _} = log_id_unpack(n)
    tag = family_byte(base_log)

    if tag == 0 do
      :unknown
    else
      Enum.find_value(@families, :unknown, fn {atom, val} ->
        if val == tag, do: atom
      end)
    end
  end

  def family_for_block(_), do: :unknown

  @doc """
  The registered derived-log families, as `{name, tag_byte}` tuples.

  Families describe the ruleset for a derived (game) log. Only registered
  families get a concrete label; other non-zero tag bytes are still valid
  derived-log families and render by their numeric tag.
  """
  @spec families() :: [{atom, 1..255}]
  def families, do: @families

  @doc """
  The tag byte for a registered family name, or `:error` if unknown.

  ## Examples

      iex> QuaggaDef.family_tag(:backgammon)
      1

      iex> QuaggaDef.family_tag(:poker)
      :error

  """
  @spec family_tag(atom) :: 1..255 | :error
  def family_tag(name) when is_atom(name) do
    Keyword.get(@families, name, :error)
  end

  @doc """
  The registered family name for a tag byte, or `:unknown` if unregistered.

  ## Examples

      iex> QuaggaDef.family_name(1)
      :backgammon

      iex> QuaggaDef.family_name(14)
      :unknown

  """
  @spec family_name(1..255) :: atom
  def family_name(tag) when is_integer(tag) and tag >= 1 and tag <= 255 do
    Enum.find_value(@families, :unknown, fn {name, t} -> if t == tag, do: name end)
  end

  defp family_byte(base_log), do: band(bsr(base_log, 48), 0xFF)

  @doc """
  The canonical bootstrap node for the `Quagga` clump.

  Returns a `{host, port}` tuple identifying the well-known peer used to
  seed peer discovery when first joining the clump.
  """
  @spec bootstrap_node :: {binary, integer}
  def bootstrap_node, do: {"quagga.zebrine.net", 8483}

  for base_log <- Map.keys(@log_to_def) do
    matches = Enum.reduce(1..255, [base_log], fn i, a -> [base_log ||| i <<< 56 | a] end)
    defp samebase_logs(n) when n in unquote(matches), do: unquote(matches)
  end

  defp samebase_logs(_), do: []
end
