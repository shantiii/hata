defmodule HataTest do
  use ExUnit.Case
  doctest Hata

  test "greets the world" do
    assert Hata.hello() == :world
  end
end
