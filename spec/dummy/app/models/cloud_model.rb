class CloudModel < OceanDynamo::Table

  set_table_name_suffix Api.basename_suffix

  primary_key :uuid, false
  read_capacity_units 10
  write_capacity_units 5

  field :uuid,                 :string
  field :credentials,          :string,      default: "blah"
  field :token,                :string
  field :steps,                :serialized,  default: []
  field :max_seconds_in_queue, :integer,     default: 1.day
  field :default_poison_limit, :integer,     default: 5
  field :default_step_time,    :integer,     default: 30
  field :created_by,           :string
  field :updated_by,           :string
  field :destroy_at,           :datetime
  field :started_at,           :datetime
  field :last_completed_step,  :integer
  field :succeeded,            :boolean,     default: false
  field :failed,               :boolean,     default: false
  field :poison,               :boolean,     default: false
  field :finished_at,          :datetime
  field :gratuitous_float,     :float,       default: 3.141592
  field :zalagadoola,          :string,      default: "Menchikaboola"
  field :list,                 :string,      default: [1, 2, 3]


  # Validations
  #validates_presence_of :uuid

  validates_each :steps do |record, attr, value|
    record.errors.add(attr, 'must be an Array') unless value.is_a?(Array)
  end 

end
