defmodule QuaggaDefTest do
  use ExUnit.Case
  doctest QuaggaDef

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
    assert length(QuaggaDef.logs_for_encoding(:cbor)) == 2816
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
end
