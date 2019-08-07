# frozen_string_literal: true

# == Schema Information
#
# Table name: demand_blocks
#
#  active         :boolean          default(TRUE), not null
#  block_duration :integer
#  block_reason   :string
#  block_time     :datetime         not null
#  block_type     :integer          default("coding_needed"), not null
#  blocker_id     :integer          not null
#  created_at     :datetime         not null
#  demand_id      :integer          not null, indexed
#  discarded_at   :datetime
#  id             :bigint(8)        not null, primary key
#  stage_id       :integer
#  unblock_reason :string
#  unblock_time   :datetime
#  unblocker_id   :integer
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_demand_blocks_on_demand_id  (demand_id)
#
# Foreign Keys
#
#  fk_rails_0c8fa8d3a7  (demand_id => demands.id)
#  fk_rails_11fee31fef  (blocker_id => team_members.id)
#  fk_rails_196a395613  (unblocker_id => team_members.id)
#  fk_rails_d25cb2ae7e  (stage_id => stages.id)
#

class DemandBlock < ApplicationRecord
  include Discard::Model

  enum block_type: { coding_needed: 0, specification_needed: 1, waiting_external_supplier: 2, customer_low_urgency: 3, integration_needed: 4, customer_unavailable: 5, other_demand_dependency: 6, external_dependency: 7 }

  belongs_to :demand
  belongs_to :stage
  belongs_to :blocker, class_name: 'TeamMember', foreign_key: :blocker_id, inverse_of: :demand_blocks
  belongs_to :unblocker, class_name: 'TeamMember', foreign_key: :unblocker_id, inverse_of: :demand_blocks

  validates :demand, :demand_id, :blocker, :block_time, :block_type, presence: true

  before_save :update_computed_fields!

  scope :for_date_interval, ->(start_date, end_date) { where('block_time BETWEEN :last_time_in AND :last_time_out', last_time_in: start_date, last_time_out: end_date) }
  scope :open, -> { where('unblock_time IS NULL') }
  scope :closed, -> { where('unblock_time IS NOT NULL') }
  scope :active, -> { where(active: true) }

  def csv_array
    [
      id,
      block_time&.iso8601,
      unblock_time&.iso8601,
      block_duration,
      demand.demand_id
    ]
  end

  def to_hash
    { blocker_username: blocker.name, block_time: block_time, block_reason: block_reason, unblock_time: unblock_time }
  end

  def activate!
    update(active: true)
  end

  def deactivate!
    update(active: false)
  end

  def total_blocked_time
    return 0 unless closed? && unblock_time > block_time

    unblock_time - block_time
  end

  private

  def closed?
    unblock_time.present?
  end

  def update_computed_fields!
    self.block_duration = TimeService.instance.compute_working_hours_for_dates(block_time, unblock_time) if unblock_time.present?
    self.stage = demand.stage_at(block_time)

    demand.send(:compute_and_update_automatic_fields)
  end
end
