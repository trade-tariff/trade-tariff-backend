# rubocop:disable Style/InstanceVariable
# rubocop:disable Style/ConstantDefinitionInBlock
# rubocop:disable Style/BeforeAfterAll
# rubocop:disable Style/LeakyConstantDeclaration

RSpec.describe Sequel::Plugins::OptimizedManyToMany do
  before(:all) do
    DB = Sequel::Model.db
    DB.extension :pg_array

    DB.drop_table?(:parents, cascade: true)
    DB.drop_table?(:children, cascade: true)
    DB.drop_table?(:grandchildren, cascade: true)
    DB.drop_table?(:parents_children, cascade: true)
    DB.drop_table?(:address, cascade: true)

    DB.create_table!(:parents) do
      primary_key :id
      String :name
    end

    DB.create_table!(:children) do
      primary_key :id
      String :name
    end

    DB.create_table!(:parents_children) do
      primary_key :id
      foreign_key :parent_id, :parents, on_delete: :cascade
      foreign_key :child_id, :children, on_delete: :cascade
    end

    DB.create_table!(:grandchildren) do
      primary_key :id
      foreign_key :child_id, :children, on_delete: :cascade
      String :name
    end

    DB.create_table!(:addresses) do
      Integer :number, null: false
      String  :postcode, null: false
      String  :street

      primary_key %i[number postcode]
    end

    DB.create_table!(:parents_addresses) do
      Integer :number, null: false
      String  :postcode, null: false
      foreign_key :parent_id, :parents, on_delete: :cascade
    end

    class Parent < Sequel::Model(DB[:parents])
      many_to_many :children,
                   class: 'Child',
                   join_table: :parents_children,
                   left_key: :parent_id,
                   left_primary_key: :id,
                   right_key: :child_id,
                   right_primary_key: :id,
                   use_optimized: false
    end

    class Child < Sequel::Model(:children)
      many_to_many :parents,
                   class: 'Parent',
                   join_table: :parents_children,
                   left_key: :parent_id,
                   left_primary_key: :id,
                   right_key: :child_id,
                   right_primary_key: :id,
                   use_optimized: false

      one_to_many :grandchildren, key: :child_id
    end

    class Grandchild < Sequel::Model(:grandchildren)
      many_to_one :child
    end

    class Address < Sequel::Model(:addresses)
      unrestrict_primary_key
      set_primary_key %i[number postcode]
    end
  end

  before do
    DB[:parents_children].delete
    Child.dataset.delete
    Parent.dataset.delete
    Grandchild.dataset.delete

    @p1 = Parent.create(name: 'P1')
    @p2 = Parent.create(name: 'P2')

    @c1 = Child.create(name: 'C1')
    @c2 = Child.create(name: 'C2')
    @c3 = Child.create(name: 'C3')

    DB[:parents_children].insert(parent_id: @p1.id, child_id: @c1.id)
    DB[:parents_children].insert(parent_id: @p1.id, child_id: @c2.id)
    DB[:parents_children].insert(parent_id: @p2.id, child_id: @c3.id)

    @g1 = Grandchild.create(name: 'G1', child: @c1)
  end

  describe 'inbuilt many_to_many load' do
    it 'loads associated children normally' do
      expect(@p1.children.map(&:name)).to contain_exactly('C1', 'C2')
      expect(@p2.children.map(&:name)).to contain_exactly('C3')
    end
  end

  describe 'with default use_optimized: true' do
    before do
      Parent.many_to_many :optimized_children,
                          class: 'Child',
                          join_table: :parents_children,
                          left_key: :parent_id,
                          left_primary_key: :id,
                          right_key: :child_id,
                          right_primary_key: :id,
                          use_optimized: true
    end

    it 'loads children with custom dataset' do
      expect(@p1.optimized_children.map(&:name)).to contain_exactly('C1', 'C2')
    end

    it 'eager loads children with optimized' do
      parents = Parent.eager(:optimized_children).all
      expect(parents.find { |p| p.id == @p1.id }.optimized_children.map(&:name)).to contain_exactly('C1', 'C2')
      expect(parents.find { |p| p.id == @p2.id }.optimized_children.map(&:name)).to contain_exactly('C3')
    end
  end

  describe 'with order and use_optimized: true' do
    before do
      Parent.many_to_many :optimized_children,
                          class: 'Child',
                          join_table: :parents_children,
                          left_key: :parent_id,
                          left_primary_key: :id,
                          right_key: :child_id,
                          right_primary_key: :id,
                          use_optimized: true,
                          order: Sequel.desc(:name)
    end

    it 'loads children with custom dataset' do
      expect(@p1.optimized_children.map(&:name)).to eq(%w[C2 C1])
    end

    it 'eager loads children with optimized' do
      parents = Parent.eager(:optimized_children).all
      expect(parents.find { |p| p.id == @p1.id }.optimized_children.map(&:name)).to eq(%w[C2 C1])
      expect(parents.find { |p| p.id == @p2.id }.optimized_children.map(&:name)).to contain_exactly('C3')
    end
  end

  describe 'with multiple order fields and use_optimized: true' do
    before do
      Parent.many_to_many :optimized_children,
                          class: 'Child',
                          join_table: :parents_children,
                          left_key: :parent_id,
                          left_primary_key: :id,
                          right_key: :child_id,
                          right_primary_key: :id,
                          use_optimized: true,
                          order: %i[name id]
    end

    it 'loads children with custom dataset' do
      expect(@p1.optimized_children.map(&:name)).to eq(%w[C1 C2])
    end

    it 'eager loads children with optimized' do
      parents = Parent.eager(:optimized_children).all
      expect(parents.find { |p| p.id == @p1.id }.optimized_children.map(&:name)).to eq(%w[C1 C2])
      expect(parents.find { |p| p.id == @p2.id }.optimized_children.map(&:name)).to contain_exactly('C3')
    end
  end

  describe 'with use_optimized_dataset: false' do
    before do
      Parent.many_to_many :cte_children,
                          class: 'Child',
                          join_table: :parents_children,
                          left_key: :parent_id,
                          left_primary_key: :id,
                          right_key: :child_id,
                          right_primary_key: :id,
                          use_optimized: true,
                          use_optimized_dataset: false
    end

    it 'uses normal dataset but optimized eager loader' do
      parents = Parent.eager(:cte_children).all
      expect(parents.find { |p| p.id == @p1.id }.cte_children.map(&:name)).to contain_exactly('C1', 'C2')
      expect(parents.find { |p| p.id == @p2.id }.cte_children.map(&:name)).to contain_exactly('C3')
    end
  end

  describe 'with nested association' do
    it 'eager loads nested associations (children → grandchildren)' do
      parents = Parent.eager(children: :grandchildren).all
      expect(parents.first.children.first.grandchildren.map(&:name)).to eq(%w[G1])
    end
  end

  describe 'with nested association and use_optimized: true' do
    before do
      Parent.many_to_many :cte_children,
                          class: 'Child',
                          join_table: :parents_children,
                          left_key: :parent_id,
                          left_primary_key: :id,
                          right_key: :child_id,
                          right_primary_key: :id,
                          use_optimized: true
    end

    it 'eager loads nested associations (children → grandchildren)' do
      parents = Parent.eager(cte_children: :grandchildren).all
      expect(parents.first.children.first.grandchildren.map(&:name)).to eq(%w[G1])
    end
  end

  describe 'with composite right primary key and use_optimized: true' do
    before do
      Parent.many_to_many :addresses,
                          class: 'Address',
                          join_table: :parents_addresses,
                          left_key: :parent_id,
                          left_primary_key: :id,
                          right_key: %i[number postcode],
                          right_primary_key: %i[number postcode],
                          use_optimized: true

      @a1 = Address.create(number: 1, postcode: 'A1')
      @a2 = Address.create(number: 2, postcode: 'A2')
      @a3 = Address.create(number: 3, postcode: 'A3')

      DB[:parents_addresses].insert(parent_id: @p1.id, number: @a1.number, postcode: @a1.postcode)
      DB[:parents_addresses].insert(parent_id: @p1.id, number: @a2.number, postcode: @a2.postcode)
      DB[:parents_addresses].insert(parent_id: @p2.id, number: @a3.number, postcode: @a3.postcode)
    end

    it 'loads address with custom dataset' do
      expect(@p1.addresses.map(&:number)).to contain_exactly(1, 2)
    end

    it 'eager loads associations (parent → addresses)' do
      parents = Parent.eager(:addresses).all
      expect(parents.find { |p| p.id == @p1.id }.addresses.map(&:number)).to contain_exactly(1, 2)
    end
  end

  describe 'with composite left primary key and use_optimized: true' do
    before do
      Address.many_to_many :people,
                           class: 'Parent',
                           join_table: :parents_addresses,
                           right_key: :parent_id,
                           right_primary_key: :id,
                           left_key: %i[number postcode],
                           left_primary_key: %i[number postcode],
                           use_optimized: true

      @a1 = Address.create(number: 1, postcode: 'A1')
      @a2 = Address.create(number: 2, postcode: 'A2')
      @a3 = Address.create(number: 3, postcode: 'A3')

      @p3 = Parent.create(name: 'P3')

      DB[:parents_addresses].insert(parent_id: @p1.id, number: @a1.number, postcode: @a1.postcode)
      DB[:parents_addresses].insert(parent_id: @p1.id, number: @a2.number, postcode: @a2.postcode)
      DB[:parents_addresses].insert(parent_id: @p2.id, number: @a3.number, postcode: @a3.postcode)
      DB[:parents_addresses].insert(parent_id: @p3.id, number: @a3.number, postcode: @a3.postcode)
    end

    it 'loads people with custom dataset' do
      expect(@a3.people.map(&:id)).to eq([@p2.id, @p3.id])
    end

    it 'eager loads associations (address → people)' do
      addresses = Address.eager(:people).all
      expect(addresses.find { |a| a.number == @a3.number && a.postcode == @a3.postcode }.people.map(&:id)).to contain_exactly(@p2.id, @p3.id)
    end
  end
end
# rubocop:enable Style/InstanceVariable
# rubocop:enable Style/ConstantDefinitionInBlock
# rubocop:enable Style/BeforeAfterAll
# rubocop:enable Style/LeakyConstantDeclaration
