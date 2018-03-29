# frozen_string_literal: true

# == Schema Information
#
# Table name: demands
#
#  id                :integer          not null, primary key
#  project_result_id :integer
#  demand_id         :string           not null
#  effort            :decimal(, )
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  demand_type       :integer          not null
#  demand_url        :string
#  commitment_date   :datetime
#  end_date          :datetime
#  created_date      :datetime         not null
#  url               :string
#  class_of_service  :integer          default("standard"), not null
#  project_id        :integer          not null
#  assignees_count   :integer          not null
#
# Indexes
#
#  index_demands_on_project_result_id  (project_result_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#

class Demand < ApplicationRecord
  enum demand_type: { feature: 0, bug: 1, performance_improvement: 2, ux_improvement: 3, chore: 4 }
  enum class_of_service: { standard: 0, expedite: 1, fixed_date: 2, intangible: 3 }

  belongs_to :project
  belongs_to :project_result, counter_cache: true
  has_many :demand_transitions, dependent: :destroy
  has_many :demand_blocks, dependent: :destroy

  validates :project, :created_date, :demand_id, :demand_type, :class_of_service, :assignees_count, presence: true

  scope :opened_in_date, ->(result_date) { where('created_date::timestamp::date = :result_date', result_date: result_date) }
  scope :finished, -> { where('end_date IS NOT NULL') }
  scope :demands_with_integration, -> { joins(project: :pipefy_config).joins(:demand_transitions).where('demands.demand_id IS NOT NULL AND pipefy_configs.active = true').uniq }

  delegate :company, to: :project
  delegate :full_name, to: :project, prefix: true

  def update_effort!
    effort_transition = demand_transitions.joins(:stage).find_by('stages.compute_effort = true')
    return if effort_transition.blank?
    update(effort: (total_working_time - blocked_working_time))
  end

  def update_created_date!
    Rails.logger.info("Updating created date card_id [#{demand_id}]")

    create_transition = demand_transitions.order(:last_time_in).first
    update(created_date: create_transition.last_time_in)
  end

  def update_project_result_for_demand!(new_project_result)
    return if project_result == new_project_result
    project_result.remove_demand!(self) if project_result.present?
    new_project_result.add_demand!(self)
  end

  def result_date
    end_date&.utc&.to_date || created_date.utc.to_date
  end

  def leadtime
    return 0 if commitment_date.blank? || end_date.blank?
    end_date - commitment_date
  end

  def total_working_time
    @effort_transition ||= demand_transitions.joins(:stage).find_by('stages.compute_effort = true')
    return 0 if @effort_transition.blank?
    TimeService.instance.compute_working_hours_for_dates(@effort_transition.last_time_in, @effort_transition.last_time_out) * assignee_effort_computation
  end

  def blocked_working_time
    @effort_transition ||= demand_transitions.joins(:stage).find_by('stages.compute_effort = true')
    return 0 if @effort_transition.blank?
    demand_blocks.closed.active.for_date_interval(@effort_transition.last_time_in, @effort_transition.last_time_out).sum(:block_duration)
  end

  def downstream?
    demand_transitions.downstream_transitions.present?
  end

  private

  def assignee_effort_computation
    return assignees_count if assignees_count == 1
    assignees_count * 0.75
  end
end
