defmodule IpAccessControlTest do
  use ExUnit.Case, async: true

  import Plug.Test

  @data [
    %{allow: "10.0.0.0", good: ["10.0.0.0"], bad: ["10.0.0.1"]},
    %{allow: "10.0.0.0/32", good: ["10.0.0.0"], bad: ["10.0.0.1"]},
    %{allow: "10.0.0.0/24", good: ["10.0.0.0", "10.0.0.127", "10.0.0.255"], bad: ["10.0.1.0"]}
  ]

  def call(conn, opts \\ []), do: IpAccessControl.call(conn, IpAccessControl.init(opts))

  describe "call/2" do
    for %{allow: allow, good: good, bad: bad} <- @data do
      test "allow #{allow}: good" do
        opts = [allow: [unquote(allow)]]

        for ip <- unquote(good) do
          {:ok, parsed_ip} = :inet.parse_strict_address(to_charlist(ip))
          conn = %{conn(:get, "/") | remote_ip: parsed_ip}

          refute call(conn, opts).halted
        end
      end

      test "allow #{allow}: bad" do
        opts = [allow: [unquote(allow)]]

        for ip <- unquote(bad) do
          {:ok, parsed_ip} = :inet.parse_strict_address(to_charlist(ip))
          conn = call(%{conn(:get, "/") | remote_ip: parsed_ip}, opts)

          assert conn.halted
          assert 401 == conn.status
          assert "Not Authenticated" == conn.resp_body
        end
      end
    end
  end

  describe "allowed?/2" do
    test "empty allow list" do
      refute IpAccessControl.allowed?("1", [])
    end

    test "nil allow list" do
      refute IpAccessControl.allowed?("1", nil)
    end

    test "nil IP address" do
      refute IpAccessControl.allowed?(nil, ["1.2.3.4"])
    end

    test "blank IP address" do
      refute IpAccessControl.allowed?("", ["1.2.3.4"])
    end

    test "incorrectly formatted IP address" do
      refute IpAccessControl.allowed?("1 2 3 4", ["1.2.3.4"])
    end

    test "invalid IP address format" do
      refute IpAccessControl.allowed?(2_130_706_433, ["127.0.0.1"])
      refute IpAccessControl.allowed?(16_909_060, ["1.2.3.4"])
    end

    for %{allow: allow, good: good, bad: bad} <- @data do
      test "allow #{allow}: good (IP as string)" do
        allowed = [unquote(allow)]

        for ip <- unquote(good) do
          assert IpAccessControl.allowed?(ip, allowed)
        end
      end

      test "allow #{allow}: good (IP as parsed tuple)" do
        allowed = [unquote(allow)]

        for ip <- unquote(good) do
          {:ok, parsed_ip} = :inet.parse_strict_address(to_charlist(ip))
          assert IpAccessControl.allowed?(parsed_ip, allowed)
        end
      end

      test "allow #{allow}: bad (IP as string)" do
        allowed = [unquote(allow)]

        for ip <- unquote(bad) do
          refute IpAccessControl.allowed?(ip, allowed)
        end
      end

      test "allow #{allow}: bad (IP as parsed tuple)" do
        allowed = [unquote(allow)]

        for ip <- unquote(bad) do
          {:ok, parsed_ip} = :inet.parse_strict_address(to_charlist(ip))
          refute IpAccessControl.allowed?(parsed_ip, allowed)
        end
      end

      test "allow #{allow}: allow as function" do
        allowed = fn -> List.wrap(unquote(allow)) end

        for ip <- unquote(good) do
          {:ok, parsed_ip} = :inet.parse_strict_address(to_charlist(ip))
          assert IpAccessControl.allowed?(ip, allowed)
          assert IpAccessControl.allowed?(parsed_ip, allowed)
        end

        for ip <- unquote(bad) do
          {:ok, parsed_ip} = :inet.parse_strict_address(to_charlist(ip))
          refute IpAccessControl.allowed?(ip, allowed)
          refute IpAccessControl.allowed?(parsed_ip, allowed)
        end
      end
    end
  end
end
