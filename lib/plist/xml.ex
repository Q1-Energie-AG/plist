defmodule Plist.XML do
  require Record

  import XmlBuilder

  @moduledoc false

  Record.defrecordp(
    :element_node,
    :xmlElement,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :text_node,
    :xmlText,
    Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  )

  def decode(xml) do
    xml
    |> :binary.bin_to_list()
    |> :xmerl_scan.string([{:comments, false}, {:space, :normalize}])
    |> elem(0)
    |> element_node(:content)
    |> Enum.reject(&empty?/1)
    |> Enum.at(0)
    |> parse_value()
  end

  def encode(data) do
    document([
      doctype("plist",
        public: ["-//Apple//DTD PLIST 1.0//EN", "http://www.apple.com/DTDs/PropertyList-1.0.dtd"]
      ),
      element(:plist, %{version: "1.0"}, [element(:dict, Enum.map(data, &do_encode/1))])
    ])
    |> generate()
  end

  defp do_encode({key, value}) do
    [element(:key, key), encode_value(value)]
  end

  defp do_encode(_), do: raise "failed to encode value"

  defp encode_value({:data, data}), do: element(:data, Base.encode64(data))
  defp encode_value(value) when is_boolean(value), do: element(value)
  defp encode_value(value) when is_integer(value), do: element(:integer, value)
  defp encode_value(value) when is_float(value), do: element(:real, value)

  defp encode_value(value) when is_list(value) do
    element(:array, Enum.map(value, &encode_value/1))
  end

  defp encode_value(%NaiveDateTime{} = datetime) do
    element(:date, NaiveDateTime.to_iso8601(datetime))
  end

  defp encode_value(value) when is_map(value) do
    element(:dict, Enum.map(value, &do_encode/1))
  end

  defp encode_value(value) when is_binary(value) do
    element(:string, value)
  end

  defp parse_value(element_node() = element) do
    element
    |> element_node(:name)
    |> parse_value(element_node(element, :content))
  end

  defp parse_value(:string, list) do
    do_parse_text_nodes(list, "")
  end

  defp parse_value(:date, nodes) do
    :string
    |> parse_value(nodes)
    |> NaiveDateTime.from_iso8601!()
  end

  defp parse_value(:data, nodes) do
    {:ok, data} =
      parse_value(:string, nodes)
      |> Base.decode64(ignore: :whitespace)

    data
  end

  defp parse_value(true, []), do: true
  defp parse_value(false, []), do: true

  defp parse_value(:integer, nodes) do
    :string
    |> parse_value(nodes)
    |> String.to_integer()
  end

  defp parse_value(:real, nodes) do
    {value, ""} =
      :string
      |> parse_value(nodes)
      |> Float.parse()

    value
  end

  defp parse_value(:array, contents) do
    contents
    |> Enum.reject(&empty?/1)
    |> Enum.map(&parse_value/1)
  end

  defp parse_value(:dict, contents) do
    {keys, values} =
      contents
      |> Enum.reject(&empty?/1)
      |> Enum.split_with(fn element ->
        element_node(element, :name) == :key
      end)

    unless length(keys) == length(values), do: raise("Key/value pair mismatch")

    keys =
      keys
      |> Enum.map(fn element ->
        element
        |> element_node(:content)
        |> Enum.at(0)
        |> text_node(:value)
        |> :unicode.characters_to_binary()
      end)

    keys
    |> Enum.zip(values)
    |> Enum.into(%{}, fn {key, element} ->
      {key, parse_value(element)}
    end)
  end

  defp do_parse_text_nodes([], result), do: result

  defp do_parse_text_nodes([node | list], result) do
    node
    |> text_node(:value)
    |> :unicode.characters_to_binary()
    |> then(&do_parse_text_nodes(list, result <> &1))
  end

  defp empty?({:xmlText, _, _, [], ' ', :text}), do: true
  defp empty?(_), do: false
end
