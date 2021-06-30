defmodule IpAccessControl.OptionsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias IpAccessControl.Options

  @parsed_v4 %RemoteIp.Block{mask: 4_294_967_295, net: 16_909_060, proto: :v4}
  @parsed_v6 %RemoteIp.Block{
    mask: 340_282_366_920_938_463_463_374_607_431_768_211_455,
    net: 5_192_455_318_486_633_616_049_570_941_239_300,
    proto: :v6
  }

  defmodule Complete do
    @moduledoc false

    def ip_access_allow_list do
      ["1.2.3.4", "1:2:3::4"]
    end

    def ip_access_on_blocked(conn, _options) do
      Plug.Conn.send_resp(conn, 321, "Contact!")
    end
  end

  defmodule AllowOnly do
    @moduledoc false

    def ip_access_allow_list do
      ["1:2:3::4", "1.2.3.4"]
    end
  end

  defmodule OnBlockedOnly do
    def ip_access_on_blocked(conn, _options) do
      Plug.Conn.send_resp(conn, 500, "Server Error")
    end
  end

  describe "pack/1" do
    test "Fails if :allow is missing" do
      assert_raise KeyError, fn ->
        Options.pack([])
      end
    end

    test "skips unknown options" do
      keys = Map.keys(Options.pack(allow: [], unknown: :option))

      refute :unknown in keys
      assert :allow in keys
      assert :on_blocked in keys
      assert :response_code_on_blocked in keys
      assert :response_body_on_blocked in keys
    end

    test "allow list" do
      assert [@parsed_v4, @parsed_v6] = Options.pack(allow: ["1.2.3.4", "1:2:3::4"])[:allow]
    end

    test "allow inline function" do
      assert is_function(Options.pack(allow: fn -> [] end)[:allow], 0)
    end

    test "allow captured function" do
      expected = &test_allow_list/0

      assert expected ==
               Options.pack(allow: &test_allow_list/0)[:allow]
    end

    test "allow MF ref" do
      assert Function.capture(Complete, :ip_access_allow_list, 0) ==
               Options.pack(allow: {Complete, :ip_access_allow_list})[:allow]
    end

    test "on_blocked default" do
      assert Function.capture(IpAccessControl, :ip_access_on_blocked, 2) ==
               Options.pack(allow: [])[:on_blocked]
    end

    test "on_blocked inline function" do
      assert is_function(Options.pack(allow: [], on_blocked: fn _, _ -> nil end)[:on_blocked], 2)
    end

    test "on_blocked captured function" do
      assert Function.capture(Complete, :ip_access_on_blocked, 2) ==
               Options.pack(allow: [], on_blocked: &Complete.ip_access_on_blocked/2)[:on_blocked]
    end

    test "on_blocked MF ref" do
      assert Function.capture(Complete, :ip_access_on_blocked, 2) ==
               Options.pack(allow: [], on_blocked: {Complete, :ip_access_on_blocked})[:on_blocked]
    end

    test "response_code_on_blocked default" do
      assert 401 == Options.pack(allow: [])[:response_code_on_blocked]
    end

    test "response_code_on_blocked override" do
      assert 500 ==
               Options.pack(allow: [], response_code_on_blocked: 500)[:response_code_on_blocked]
    end

    test "response_body_on_blocked default" do
      assert "Not Authenticated" == Options.pack(allow: [])[:response_body_on_blocked]
    end

    test "response_body_on_blocked override" do
      assert "Something happened" ==
               Options.pack(allow: [], response_body_on_blocked: "Something happened")[
                 :response_body_on_blocked
               ]
    end

    test "module: Complete" do
      packed = Options.pack(module: Complete)
      assert Function.capture(Complete, :ip_access_allow_list, 0) == packed[:allow]
      assert Function.capture(Complete, :ip_access_on_blocked, 2) == packed[:on_blocked]
    end

    test "module: Complete with allow and on_blocked" do
      packed =
        Options.pack(
          module: Complete,
          allow: &AllowOnly.ip_access_allow_list/2,
          on_blocked: &OnBlockedOnly.ip_access_on_blocked/2
        )

      assert Function.capture(Complete, :ip_access_allow_list, 0) == packed[:allow]
      assert Function.capture(Complete, :ip_access_on_blocked, 2) == packed[:on_blocked]
    end

    test "module: AllowOnly" do
      packed = Options.pack(module: AllowOnly)
      assert Function.capture(AllowOnly, :ip_access_allow_list, 0) == packed[:allow]
      assert Function.capture(IpAccessControl, :ip_access_on_blocked, 2) == packed[:on_blocked]
    end

    test "module: OnBlockedOnly (failure)" do
      assert_raise KeyError, fn ->
        Options.pack(module: OnBlockedOnly)
      end
    end

    test "module: OnBlockedOnly with allow" do
      packed = Options.pack(module: OnBlockedOnly, allow: [])
      assert [] == packed[:allow]
      assert Function.capture(OnBlockedOnly, :ip_access_on_blocked, 2) == packed[:on_blocked]
    end
  end

  describe "unpack/1" do
    def pack_unpack(options) do
      packed = Options.pack(options)
      unpacked = Options.unpack(packed)
      {packed, unpacked}
    end

    test "allow list" do
      {packed, unpacked} = pack_unpack(allow: [])

      assert packed[:allow] == unpacked[:allow]
    end

    test "allow inline function" do
      {_packed, unpacked} = pack_unpack(allow: fn -> ["1.2.3.4"] end)
      assert [@parsed_v4] == unpacked[:allow]
    end

    test "allow captured function" do
      {_packed, unpacked} = pack_unpack(allow: &test_allow_list/0)
      assert [@parsed_v4] == unpacked[:allow]
    end

    test "allow MF ref" do
      {_packed, unpacked} = pack_unpack(allow: {Complete, :ip_access_allow_list})
      assert [@parsed_v4, @parsed_v6] == unpacked[:allow]
    end

    test "on_blocked default" do
      {packed, unpacked} = pack_unpack(allow: [])
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end

    test "on_blocked inline function" do
      {packed, unpacked} = pack_unpack(allow: [], on_blocked: fn _, _ -> nil end)
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end

    test "on_blocked captured function" do
      {packed, unpacked} = pack_unpack(allow: [], on_blocked: &Complete.ip_access_on_blocked/2)
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end

    test "on_blocked MF ref" do
      {packed, unpacked} = pack_unpack(allow: [], on_blocked: {Complete, :ip_access_on_blocked})
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end

    test "response_code_on_blocked default" do
      {packed, unpacked} = pack_unpack(allow: [])
      assert packed[:response_code_on_blocked] == unpacked[:response_code_on_blocked]
    end

    test "response_code_on_blocked override" do
      {packed, unpacked} = pack_unpack(allow: [], response_code_on_blocked: 500)
      assert packed[:response_code_on_blocked] == unpacked[:response_code_on_blocked]
    end

    test "response_body_on_blocked default" do
      {packed, unpacked} = pack_unpack(allow: [])
      assert packed[:response_body_on_blocked] == unpacked[:response_body_on_blocked]
    end

    test "response_body_on_blocked override" do
      {packed, unpacked} = pack_unpack(allow: [], response_body_on_blocked: "Something happened")
      assert packed[:response_body_on_blocked] == unpacked[:response_body_on_blocked]
    end

    test "module: Complete" do
      {packed, unpacked} = pack_unpack(module: Complete)
      assert [@parsed_v4, @parsed_v6] == unpacked[:allow]
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end

    test "module: Complete with allow and on_blocked" do
      {packed, unpacked} =
        pack_unpack(
          module: Complete,
          allow: &AllowOnly.ip_access_allow_list/2,
          on_blocked: &OnBlockedOnly.ip_access_on_blocked/2
        )

      assert [@parsed_v4, @parsed_v6] == unpacked[:allow]
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end

    test "module: AllowOnly" do
      {packed, unpacked} = pack_unpack(module: AllowOnly)

      assert [@parsed_v6, @parsed_v4] == unpacked[:allow]
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end

    test "module: OnBlockedOnly with allow" do
      {packed, unpacked} = pack_unpack(module: OnBlockedOnly, allow: [])
      assert [] == unpacked[:allow]
      assert packed[:on_blocked] == unpacked[:on_blocked]
    end
  end

  def test_allow_list do
    ["1.2.3.4"]
  end
end
