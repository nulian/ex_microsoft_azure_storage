defmodule Microsoft.Azure.Storage.BlobPolicy do
  import SweetXml
  require EEx

  defstruct [:id, :start, :expiry, :permission]

  def permission_serialize(list) when is_list(list), do: list |> Enum.uniq() |> perm_ser("")

  defp perm_ser([], acc), do: acc
  defp perm_ser([:read | tail], acc), do: tail |> perm_ser("r" <> acc)
  defp perm_ser([:write | tail], acc), do: tail |> perm_ser("w" <> acc)
  defp perm_ser([:delete | tail], acc), do: tail |> perm_ser("d" <> acc)
  defp perm_ser([:list | tail], acc), do: tail |> perm_ser("l" <> acc)
  # @blob_permissions %{read: "r", write: "w", delete: "d", list: "l"}
  # defp perm_ser([a | tail], acc) when is_atom(a), do: tail |> perm_ser(Map.get(@blob_permissions, a, "") <> acc)

  defp perm_ser([unknown | _tail], _acc) when is_atom(unknown),
    do: raise("Received unknown permission #{inspect(unknown)}")

  def permission_parse(str) when is_binary(str), do: str |> perm([]) |> Enum.uniq()
  defp perm("", acc), do: acc
  defp perm("r" <> str, acc), do: str |> perm([:read | acc])
  defp perm("w" <> str, acc), do: str |> perm([:write | acc])
  defp perm("d" <> str, acc), do: str |> perm([:delete | acc])
  defp perm("l" <> str, acc), do: str |> perm([:list | acc])

  defp perm(unknown, _acc) when is_binary(unknown),
    do: raise("Received unknown permission #{inspect(unknown)}")

  def deserialize(xml_body) do
    xml_body
    |> xpath(~x"/SignedIdentifiers/SignedIdentifier"l)
    |> Enum.map(fn node ->
      %__MODULE__{
        id: node |> xpath(~x"./Id/text()"s),
        start: node |> xpath(~x"./AccessPolicy/Start/text()"s),
        expiry: node |> xpath(~x"./AccessPolicy/Expiry/text()"s),
        permission:
          node
          |> xpath(~x"./AccessPolicy/Permission/text()"s |> transform_by(&permission_parse/1))
      }
    end)
  end

  @template """
  <SignedIdentifiers>
    <%= for policy <- @policies do %>
    <SignedIdentifier>
      <Id><%= policy.id %></Id>
      <AccessPolicy>
        <Start><%= policy.start %></Start>
        <Expiry><%= policy.expiry %></Expiry>
        <Permission><%= policy.permission |> Microsoft.Azure.Storage.BlobPolicy.permission_serialize() %></Permission>
      </AccessPolicy>
    </SignedIdentifier>
    <% end %>
  </SignedIdentifiers>
  """

  def serialize(policies) when is_list(policies),
    do: @template |> EEx.eval_string(assigns: [policies: policies])

  # def serialize(policy = %__MODULE__{}) when is_map(policy),
  #   do:
  #     "<SignedIdentifier><Id>#{policy.id}</Id><AccessPolicy>" <>
  #       "<Start>#{policy.start}</Start><Expiry>#{policy.expiry}</Expiry>" <>
  #       "<Permission>#{policy.permission}</Permission>" <> "</AccessPolicy></SignedIdentifier>"

  # def serialize(policies) when is_list(policies) do
  #   inner_xml =
  #     policies
  #     |> Enum.map(&serialize/1)
  #     |> Enum.join("")
  #   "<SignedIdentifiers>#{inner_xml}</SignedIdentifiers>"
  # end
end