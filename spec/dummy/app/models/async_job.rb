class AsyncJob < OceanDynamo::Table

  ocean_resource_model index: [:uuid], search: false,
                       invalidate_member: [],
                       invalidate_collection: []

  primary_key :uuid

  field :uuid,                 :string
  field :credentials,          :string
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
  field :finished_at,          :datetime
  field :succeeded,            :boolean,     default: false
  field :failed,               :boolean,     default: false
  field :poison,               :boolean,     default: false


  @@queue = nil


  # Validations
  validates_each :steps do |record, attr, value|
    record.errors.add(attr, 'must be an Array') unless value.is_a?(Array)
  end 

  validates :credentials, presence: { message: "must be specified", on: :create }

  validates_each :credentials, on: :create, allow_blank: true do |job, attr, val|
    username, password = Api.decode_credentials val
    job.errors.add(attr, "are malformed") if username.blank? || password.blank?
  end


  # Callbacks
  before_validation do |j| 
    j.destroy_at ||= Time.now.utc + j.max_seconds_in_queue
  end

  after_create do |j|
    j.enqueue unless j.steps == []
  end

  after_update  { |model| model.ban }
  after_destroy { |model| model.ban }


  #
  # Finishes the job successfully. Returns true.
  #
  def job_succeeded
    self.finished_at = Time.now.utc
    self.succeeded = true
    save!
    Rails.logger.info "[Job #{uuid}] succeeded (#{steps.length} steps)."
    true
  end

  #
  # Finishes the job as failed. Returns true.
  #
  def job_failed(str=nil)
    self.finished_at = Time.now.utc
    self.failed = true
    save!
    log(str) if str
    Rails.logger.warn "[Job #{uuid}] failed: '#{str}' (#{steps.length} steps)."
    true
  end

  #
  # Finishes the job as poison. Returns true.
  #
  def job_is_poison
    self.finished_at = Time.now.utc
    self.poison = true
    self.failed = true
    save!
    Rails.logger.error "[Job #{uuid}] is poison (#{steps.length} steps)."
    true
  end


  #
  # Returns true if the whole job is finished, regardless of how it finished 
  # (success, failure, poison)
  #
  def finished?
    !!finished_at
  end


  #
  # Returns the index of the current step
  #
  def current_step_index
    (last_completed_step || -1) + 1
  end

  #
  # Returns the current step
  #
  def current_step
    steps[current_step_index]
  end

  #
  # Returns true if there are no more steps
  #
  def done_all_steps?
    !current_step
  end

  #
  # Advances the job to the next step
  #
  def current_step_done!
    return if finished?
    self.last_completed_step = current_step_index
    job_succeeded if done_all_steps? && !failed?
    save!
  end


  #
  # Poison limit for the current step
  #
  def poison_limit
    cs = current_step
    cs && cs['poison_limit'] || default_poison_limit
  end

  #
  # Step time for the current step
  #
  def step_time
    cs = current_step
    cs && cs['step_time'] || default_step_time
  end


  #
  # This method enqueues the job on AWS.
  #
  def enqueue
    @@queue ||= AsyncJobQueue.new basename: ASYNCJOBQ_AWS_BASENAME
    @@queue.send_message uuid
  end


  #
  # Log to the current step.
  # 
  def log(str)
    cs = current_step
    cs['log'] ||= []
    cs['log'] << str
    save!
    str
  end


  #
  # Issue a BAN to remove the entity from Varnish
  #
  def ban
    Api.ban "/#{Api.version_for(:async_jobs)}/async_jobs/#{uuid}"
  end

end
