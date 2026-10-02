defmodule QuaggaDefTest do
  use ExUnit.Case
  doctest QuaggaDef
  import Bitwise

  test "log_id_unpack" do
    assert :error == QuaggaDef.log_id_unpack(:test)
    assert {0, 0} == QuaggaDef.log_id_unpack(0)
    assert {72_057_594_037_927_935, 0} == QuaggaDef.log_id_unpack(72_057_594_037_927_935)
    assert {0, 1} == QuaggaDef.log_id_unpack(72_057_594_037_927_936)
    assert {72_057_594_037_927_935, 1} == QuaggaDef.log_id_unpack(144_115_188_075_855_871)
    assert {0, 2} == QuaggaDef.log_id_unpack(144_115_188_075_855_872)
  end

  test "log_defs" do
    # This one we're probaly stuck with forever
    assert %{0 => %{encoding: :raw, type: "text/plain", name: :test}} = QuaggaDef.log_defs()
  end

  test "log_def" do
    # This one is a bit on the nose
    ali = %{encoding: :cbor, type: :map, name: :alias}
    assert ali == QuaggaDef.log_def(53)
    assert ali == QuaggaDef.log_def(72_057_594_037_927_989)
    assert %{} == QuaggaDef.log_def(72_057_594_037_927_990)
    assert :error == QuaggaDef.log_def(:alias)
  end

  test "base_log" do
    assert 53 == QuaggaDef.base_log(:alias)
    assert 0 == QuaggaDef.base_log(:test)
    assert :error == QuaggaDef.base_log(:private)
    assert 53 == QuaggaDef.base_log(53)
    assert 53 == QuaggaDef.base_log(72_057_594_037_927_989)
    assert 0 == QuaggaDef.base_log(72_057_594_037_927_936)
    assert 8008 == QuaggaDef.base_log("image/jpeg")
    assert :error == QuaggaDef.base_log("test")
  end

  test "logs_for_name" do
    assert length(QuaggaDef.logs_for_name(:alias)) == 256
    assert length(QuaggaDef.logs_for_name(:private)) == 0
  end

  test "logs_for_encoding" do
    # On the nose
    assert length(QuaggaDef.logs_for_encoding(:raw)) == 1024
    assert length(QuaggaDef.logs_for_encoding(:cbor)) == 3072
    assert length(QuaggaDef.logs_for_encoding(:xml)) == 0
  end

  test "facet_log" do
    assert 0 == QuaggaDef.facet_log(0, 0)
    assert 0 == QuaggaDef.facet_log(:test, 0)
    assert 1 == QuaggaDef.facet_log(1, 0)
    assert 18_446_744_073_709_551_615 == QuaggaDef.facet_log(72_057_594_037_927_935, 255)
    assert :error == QuaggaDef.facet_log(72_057_594_037_927_936, 0)
    assert :error == QuaggaDef.facet_log(0, 256)
    assert :error == QuaggaDef.facet_log(:private, 0)
  end

  test "bootstrap_node" do
    assert {"quagga.zebrine.net", 8483} == QuaggaDef.bootstrap_node()
  end

  test "challenge log" do
    chal = %{encoding: :cbor, type: :map, name: :challenge}

    assert 777 == QuaggaDef.base_log(:challenge)
    assert chal == QuaggaDef.log_def(777)
    assert chal == QuaggaDef.log_def(777)

    # Facet iteration over the challenge log yields a full set
    assert length(QuaggaDef.logs_for_name(:challenge)) == 256
    # The un-faceted id is the first in the set
    assert 777 in QuaggaDef.logs_for_name(:challenge)
    # And a specific facet
    assert 72_057_594_037_928_713 == QuaggaDef.facet_log(:challenge, 1)
  end

  test "reserved_base_log?" do
    # All hand-allocated log ids are in the low 48 bits (not reserved)
    assert false == QuaggaDef.reserved_base_log?(0)
    assert false == QuaggaDef.reserved_base_log?(777)
    assert false == QuaggaDef.reserved_base_log?(360_360)

    # Derived ids carry the reserved marker nibble
    assert true == QuaggaDef.reserved_base_log?(QuaggaDef.derived_log_base(1))

    # Even with a facet applied, the base remains derived/reserved
    game_log_id = QuaggaDef.facet_log(QuaggaDef.derived_log_base(1), 7)
    assert true == QuaggaDef.reserved_base_log?(game_log_id)
  end

  test "derived_log_base" do
    # Backgammon family default: family tag 0x1 placed in bits 48..55
    assert 281_474_976_710_656 == QuaggaDef.derived_log_base(0)

    # A different family tag lands in the same reserved space with a distinct byte
    assert 562_949_953_421_312 == QuaggaDef.derived_log_base(0, 2)
    assert QuaggaDef.derived_log_base(0, 1) != QuaggaDef.derived_log_base(0, 2)

    # Result always has the reserved family byte set and stays in the base range
    for n <- [0, 1, 65535, 0xFFFFFFFF, 2_000_000_000_000_000_000] do
      dl = QuaggaDef.derived_log_base(n)
      assert dl >= 1 <<< 48
      assert dl <= 72_057_594_037_927_935
      assert true == QuaggaDef.reserved_base_log?(dl)
    end

    # Two different inputs fold to different derived bases (low 48 bits preserved)
    assert QuaggaDef.derived_log_base(1) != QuaggaDef.derived_log_base(2)
  end

  test "family_for_block" do
    # Hand-allocated log ids are :unknown
    assert :unknown == QuaggaDef.family_for_block(0)
    assert :unknown == QuaggaDef.family_for_block(777)

    # Backgammon tags resolve to :backgammon
    assert :backgammon == QuaggaDef.family_for_block(QuaggaDef.derived_log_base(1_234_567))
    assert :backgammon == QuaggaDef.family_for_block(QuaggaDef.derived_log_base(0, 1))

    # A game log id (facet applied) still resolves to :backgammon
    game_log_id = QuaggaDef.facet_log(QuaggaDef.derived_log_base(42), 7)
    assert :backgammon == QuaggaDef.family_for_block(game_log_id)

    # An unrecognized family tag is :unknown
    assert :unknown == QuaggaDef.family_for_block(QuaggaDef.derived_log_base(1, 14))
  end

  test "families" do
    families = QuaggaDef.families()
    assert is_list(families)
    assert [{:app, 2}, {:backgammon, 1}] == families
  end

  test "family_tag" do
    assert 1 == QuaggaDef.family_tag(:backgammon)
    assert 2 == QuaggaDef.family_tag(:app)
    assert :error == QuaggaDef.family_tag(:poker)
  end

  test "family_name" do
    assert :backgammon == QuaggaDef.family_name(1)
    assert :app == QuaggaDef.family_name(2)
    assert :unknown == QuaggaDef.family_name(14)
    assert :unknown == QuaggaDef.family_name(255)
  end

  test "app listing log" do
    listing = %{encoding: :cbor, type: :map, name: :listing}

    assert 2777 == QuaggaDef.base_log(:listing)
    assert listing == QuaggaDef.log_def(2777)
    assert listing == QuaggaDef.log_def(QuaggaDef.facet_log(2777, 1))

    # It is hand-allocated, so it never reads as a derived family log
    assert false == QuaggaDef.reserved_base_log?(2777)
    assert :unknown == QuaggaDef.family_for_block(2777)

    # Facet iteration over the listing log yields a full set
    assert length(QuaggaDef.logs_for_name(:listing)) == 256
    assert 2777 in QuaggaDef.logs_for_name(:listing)
  end

  test "family_defs" do
    defs = QuaggaDef.family_defs()

    assert %{tag: 1, control_log: :challenge} == defs[:backgammon]
    assert %{tag: 2, control_log: :listing} == defs[:app]
    assert nil == defs[:poker]
  end

  test "control_log" do
    assert 777 == QuaggaDef.control_log(:backgammon)
    assert 2777 == QuaggaDef.control_log(:app)
    assert :error == QuaggaDef.control_log(:poker)
  end

  test "control_logs" do
    backgammon_logs = QuaggaDef.control_logs(:backgammon)
    assert length(backgammon_logs) == 256
    assert backgammon_logs == QuaggaDef.logs_for_name(:challenge)

    app_logs = QuaggaDef.control_logs(:app)
    assert length(app_logs) == 256
    assert app_logs == QuaggaDef.logs_for_name(:listing)

    assert [] == QuaggaDef.control_logs(:poker)

    all = QuaggaDef.control_logs()
    assert length(all) == 512
    assert Enum.sort(all) == all
    assert Enum.uniq(all) == all
    assert MapSet.new(app_logs ++ backgammon_logs) == MapSet.new(all)
  end

  test "a control log announces every family registered to it, not just one" do
    for {name, %{tag: tag, control_log: control}} <- QuaggaDef.family_defs() do
      assert {name, tag} in QuaggaDef.families_for_control_log(control)

      # The three views of a control log agree: id, atom, and the family's own
      id = QuaggaDef.control_log(name)
      assert control == QuaggaDef.family_control_log(name)
      assert control == QuaggaDef.log_def(id).name
      assert QuaggaDef.families_for_control_log(id) == QuaggaDef.families_for_control_log(control)
    end

    assert QuaggaDef.families_for_control_log(777) ==
             QuaggaDef.families_for_control_log(:challenge)

    assert QuaggaDef.families_for_control_log(2777) ==
             QuaggaDef.families_for_control_log(:listing)

    assert QuaggaDef.families_for_control_log(QuaggaDef.facet_log(:listing, 3)) == [app: 2]
  end

  test "family_control_log" do
    assert :challenge == QuaggaDef.family_control_log(:backgammon)
    assert :listing == QuaggaDef.family_control_log(:app)

    # Unregistered family names
    assert :error == QuaggaDef.family_control_log(:poker)
    assert :error == QuaggaDef.family_control_log(:unknown)
    assert :error == QuaggaDef.family_control_log("backgammon")
  end

  test "families_for_control_log" do
    # By control log name, base id, and facetted id
    assert [backgammon: 1] == QuaggaDef.families_for_control_log(:challenge)
    assert [backgammon: 1] == QuaggaDef.families_for_control_log(777)

    assert [backgammon: 1] ==
             QuaggaDef.families_for_control_log(QuaggaDef.facet_log(:challenge, 9))

    assert [app: 2] == QuaggaDef.families_for_control_log(:listing)
    assert [app: 2] == QuaggaDef.families_for_control_log(2777)

    # A control log announcing no family, and junk
    assert [] == QuaggaDef.families_for_control_log(:graph)
    assert [] == QuaggaDef.families_for_control_log(1337)
    assert [] == QuaggaDef.families_for_control_log(QuaggaDef.derived_log_base(1))
    assert [] == QuaggaDef.families_for_control_log("777")

    # A family name is not a control log; use family_control_log/1 to invert
    assert [] == QuaggaDef.families_for_control_log(:backgammon)

    # The partition covers every registered family exactly once
    all = QuaggaDef.families()

    partitioned =
      QuaggaDef.control_logs()
      |> Enum.flat_map(&QuaggaDef.families_for_control_log/1)
      |> Enum.uniq()

    assert Enum.sort(all) == Enum.sort(partitioned)
  end
end
