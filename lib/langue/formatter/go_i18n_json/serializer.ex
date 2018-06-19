defmodule Langue.Formatter.GoI18nJson.Serializer do
  @behaviour Langue.Formatter.Serializer

  alias Langue.Utils.NestedSerializerHelper

  def serialize(%{entries: entries}) do
    render =
      entries
      |> Enum.reduce(%{current_plural: [], entries: []}, fn
        entry = %{plural: true}, acc ->
          acc
          |> update_in([:current_plural], &(&1 ++ [entry]))

        entry = %{plural: false}, acc = %{current_plural: current_plural} when current_plural !== [] ->
          acc
          |> update_in([:entries], &(&1 ++ [{[{"id", plurals_to_key(current_plural)}, {"translation", map_plurals(current_plural)}]}]))
          |> update_in([:entries], &(&1 ++ [{[{"id", entry.key}, {"translation", entry_value(entry)}]}]))

        entry, acc ->
          acc
          |> update_in([:entries], &(&1 ++ [{[{"id", entry.key}, {"translation", entry_value(entry)}]}]))
      end)
      |> case do
        acc = %{current_plural: current_plural} when current_plural !== [] ->
          acc
          |> update_in([:entries], &(&1 ++ [{[{"id", plurals_to_key(current_plural)}, {"translation", {map_plurals(current_plural)}}]}]))

        acc ->
          acc
      end
      |> Map.get(:entries)
      |> :jiffy.encode([:pretty])
      |> String.replace(~r/\" : (\"|{|\[|null|false|true|\d)/, "\": \\1")
      |> Kernel.<>("\n")

    %Langue.Formatter.SerializerResult{render: render}
  end

  defp plurals_to_key([entry | _]) do
    plural_string =
      Regex.named_captures(~r/\.(?<plural>\w+)$/, entry.key)
      |> Map.get("plural")

    String.replace(entry.key, "." <> plural_string, "")
  end

  defp map_plurals(plurals) do
    root_key = plurals_to_key(plurals)

    Enum.map(plurals, fn entry ->
      {String.replace(entry.key, root_key <> ".", ""), entry_value(entry)}
    end)
  end

  defp entry_value(%{value_type: "null"}), do: :null
  defp entry_value(entry), do: NestedSerializerHelper.entry_value_to_string(entry.value, entry.value_type)
end
