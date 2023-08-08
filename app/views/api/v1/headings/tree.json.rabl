object @heading
attributes :id, :declarable

child(@heading.descendants) do
  attributes :id
end
