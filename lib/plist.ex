defmodule Plist do
  @moduledoc """
  The entry point for reading plist data.
  """

  alias Plist.{Binary, XML}

  @type result :: map()
  @type format :: :binary | :xml

  @doc """
  Parse the data provided as an XML or binary format plist,
  depending on the header.
  """
  @spec decode(String.t()) :: result
  def decode("bplist00" <> _rest = data), do: Binary.decode(data)
  def decode("<?xml ve" <> _rest = data), do: XML.decode(data)
  def decode(_data), do: raise("Unknown plist format")

  @spec encode(map(), format()) :: binary()
  def encode(data, format \\ :xml)
  def encode(data, :xml), do: XML.encode(data)
  def encode(data, :binary), do: Binary.encode(data)

  @doc false
  @deprecated "Use decode/1 instead"
  @doc since: "0.0.6"
  def parse(data), do: decode(data)
end
