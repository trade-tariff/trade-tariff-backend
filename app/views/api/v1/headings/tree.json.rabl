object @heading
attributes :id, :declarable

child(@heading.ns_descendants) do
  attributes :id
end
