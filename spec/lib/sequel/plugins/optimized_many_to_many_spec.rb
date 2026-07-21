RSpec.describe Sequel::Plugins::OptimizedManyToMany do
  let(:parent_one) { Parent.create(name: 'P1') }
  let(:parent_two) { Parent.create(name: 'P2') }
  let(:child_one) { Child.create(name: 'C1') }

  before do
    create_schema
    define_models
    create_fixture_records
  end

  def create_fixture_records
    child_one
    child_two = Child.create(name: 'C2')
    child_three = Child.create(name: 'C3')

    Sequel::Model.db[:parents_children].insert(parent_id: parent_one.id, child_id: child_one.id)
    Sequel::Model.db[:parents_children].insert(parent_id: parent_one.id, child_id: child_two.id)
    Sequel::Model.db[:parents_children].insert(parent_id: parent_two.id, child_id: child_three.id)
    Grandchild.create(name: 'G1', child: child_one)
  end

  def create_schema
    db = Sequel::Model.db
    db.extension :pg_array

    db.drop_table?(:parents, cascade: true)
    db.drop_table?(:children, cascade: true)
    db.drop_table?(:grandchildren, cascade: true)
    db.drop_table?(:parents_children, cascade: true)
    db.drop_table?(:addresses, cascade: true)
    db.drop_table?(:parents_addresses, cascade: true)

    db.create_table!(:parents) do
      primary_key :id
      String :name
    end

    db.create_table!(:children) do
      primary_key :id
      String :name
    end

    db.create_table!(:parents_children) do
      primary_key :id
      foreign_key :parent_id, :parents, on_delete: :cascade
      foreign_key :child_id, :children, on_delete: :cascade
    end

    db.create_table!(:grandchildren) do
      primary_key :id
      foreign_key :child_id, :children, on_delete: :cascade
      String :name
    end

    db.create_table!(:addresses) do
      Integer :number, null: false
      String  :postcode, null: false
      String  :street

      primary_key %i[number postcode]
    end

    db.create_table!(:parents_addresses) do
      Integer :number, null: false
      String  :postcode, null: false
      foreign_key :parent_id, :parents, on_delete: :cascade
    end
  end

  def define_models
    stub_const('Parent', Class.new(Sequel::Model(:parents)))
    stub_const('Child', Class.new(Sequel::Model(:children)))
    stub_const('Grandchild', Class.new(Sequel::Model(:grandchildren)))
    stub_const('Address', Class.new(Sequel::Model(:addresses)))

    Parent.many_to_many :children,
                        class: 'Child',
                        join_table: :parents_children,
                        left_key: :parent_id,
                        left_primary_key: :id,
                        right_key: :child_id,
                        right_primary_key: :id,
                        use_optimized: false

    Child.many_to_many :parents,
                       class: 'Parent',
                       join_table: :parents_children,
                       left_key: :parent_id,
                       left_primary_key: :id,
                       right_key: :child_id,
                       right_primary_key: :id,
                       use_optimized: false
    Child.one_to_many :grandchildren, key: :child_id
    Grandchild.many_to_one :child
    Address.unrestrict_primary_key
    Address.set_primary_key %i[number postcode]
  end

  describe 'inbuilt many_to_many load' do
    it 'loads associated children normally' do
      expect(parent_one.children.map(&:name)).to contain_exactly('C1', 'C2')
      expect(parent_two.children.map(&:name)).to contain_exactly('C3')
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
      expect(parent_one.optimized_children.map(&:name)).to contain_exactly('C1', 'C2')
    end

    it 'eager loads children with optimized' do
      parents = Parent.eager(:optimized_children).all
      expect(parents.find { |p| p.id == parent_one.id }.optimized_children.map(&:name)).to contain_exactly('C1', 'C2')
      expect(parents.find { |p| p.id == parent_two.id }.optimized_children.map(&:name)).to contain_exactly('C3')
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
      expect(parent_one.optimized_children.map(&:name)).to eq(%w[C2 C1])
    end

    it 'eager loads children with optimized' do
      parents = Parent.eager(:optimized_children).all
      expect(parents.find { |p| p.id == parent_one.id }.optimized_children.map(&:name)).to eq(%w[C2 C1])
      expect(parents.find { |p| p.id == parent_two.id }.optimized_children.map(&:name)).to contain_exactly('C3')
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
      expect(parent_one.optimized_children.map(&:name)).to eq(%w[C1 C2])
    end

    it 'eager loads children with optimized' do
      parents = Parent.eager(:optimized_children).all
      expect(parents.find { |p| p.id == parent_one.id }.optimized_children.map(&:name)).to eq(%w[C1 C2])
      expect(parents.find { |p| p.id == parent_two.id }.optimized_children.map(&:name)).to contain_exactly('C3')
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
      expect(parents.find { |p| p.id == parent_one.id }.cte_children.map(&:name)).to contain_exactly('C1', 'C2')
      expect(parents.find { |p| p.id == parent_two.id }.cte_children.map(&:name)).to contain_exactly('C3')
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

    it 'eager loads nested associations (cte_children → grandchildren)' do
      parents = Parent.eager(cte_children: :grandchildren).all
      p1 = parents.find { |p| p.id == parent_one.id }
      c1 = p1.cte_children.find { |c| c.id == child_one.id }
      expect(c1.grandchildren.map(&:name)).to eq(%w[G1])
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

      address_one = Address.create(number: 1, postcode: 'A1')
      address_two = Address.create(number: 2, postcode: 'A2')
      address_three = Address.create(number: 3, postcode: 'A3')

      Sequel::Model.db[:parents_addresses].insert(
        parent_id: parent_one.id,
        number: address_one.number,
        postcode: address_one.postcode,
      )
      Sequel::Model.db[:parents_addresses].insert(
        parent_id: parent_one.id,
        number: address_two.number,
        postcode: address_two.postcode,
      )
      Sequel::Model.db[:parents_addresses].insert(
        parent_id: parent_two.id,
        number: address_three.number,
        postcode: address_three.postcode,
      )
    end

    it 'loads address with custom dataset' do
      expect(parent_one.addresses.map(&:number)).to contain_exactly(1, 2)
    end

    it 'eager loads associations (parent → addresses)' do
      parents = Parent.eager(:addresses).all
      eager_parent = parents.find { |parent| parent.id == parent_one.id }

      expect(eager_parent.addresses.map(&:number)).to contain_exactly(1, 2)
    end
  end

  describe 'with composite left primary key and use_optimized: true' do
    let(:address_three) { Address.create(number: 3, postcode: 'A3') }
    let(:parent_three) { Parent.create(name: 'P3') }

    before do
      Address.many_to_many :people,
                           class: 'Parent',
                           join_table: :parents_addresses,
                           right_key: :parent_id,
                           right_primary_key: :id,
                           left_key: %i[number postcode],
                           left_primary_key: %i[number postcode],
                           use_optimized: true

      insert_parent_address(parent_one, Address.create(number: 1, postcode: 'A1'))
      insert_parent_address(parent_one, Address.create(number: 2, postcode: 'A2'))
      insert_parent_address(parent_two, address_three)
      insert_parent_address(parent_three, address_three)
    end

    it 'loads people with custom dataset' do
      expect(address_three.people.map(&:id)).to eq([parent_two.id, parent_three.id])
    end

    it 'eager loads associations (address → people)' do
      addresses = Address.eager(:people).all
      eager_address = addresses.find do |address|
        address.number == address_three.number && address.postcode == address_three.postcode
      end

      expect(eager_address.people.map(&:id)).to contain_exactly(
        parent_two.id,
        parent_three.id,
      )
    end
  end

  def insert_parent_address(parent, address)
    Sequel::Model.db[:parents_addresses].insert(
      parent_id: parent.id,
      number: address.number,
      postcode: address.postcode,
    )
  end
end
