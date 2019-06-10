# frozen_string_literal: true

# == Schema Information
#
# Table name: demands
#
#  artifact_type     :integer          default("story")
#  assignees_count   :integer          default(0), not null
#  class_of_service  :integer          default("standard"), not null
#  commitment_date   :datetime
#  company_id        :integer          not null, indexed => [demand_id]
#  created_at        :datetime         not null
#  created_date      :datetime         not null
#  demand_id         :string           not null, indexed => [company_id]
#  demand_title      :string
#  demand_type       :integer          not null
#  demand_url        :string
#  discarded_at      :datetime         indexed
#  effort_downstream :decimal(, )      default(0.0)
#  effort_upstream   :decimal(, )      default(0.0)
#  end_date          :datetime
#  id                :bigint(8)        not null, primary key
#  leadtime          :decimal(, )
#  manual_effort     :boolean          default(FALSE)
#  parent_id         :integer
#  project_id        :integer          not null
#  slug              :string           indexed
#  total_queue_time  :integer          default(0)
#  total_touch_time  :integer          default(0)
#  updated_at        :datetime         not null
#  url               :string
#
# Indexes
#
#  index_demands_on_demand_id_and_company_id  (demand_id,company_id) UNIQUE
#  index_demands_on_discarded_at              (discarded_at)
#  index_demands_on_slug                      (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_19bdd8aa1e  (project_id => projects.id)
#  fk_rails_1abfdc9ca0  (parent_id => demands.id)
#

class Demand < ApplicationRecord
  include Discard::Model

  extend FriendlyId
  friendly_id :demand_id, use: :slugged

  enum artifact_type: { story: 0, epic: 1, theme: 2 }
  enum demand_type: { feature: 0, bug: 1, performance_improvement: 2, ui: 3, chore: 4, wireframe: 5 }
  enum class_of_service: { standard: 0, expedite: 1, fixed_date: 2, intangible: 3 }

  belongs_to :project
  belongs_to :company

  belongs_to :parent, class_name: 'Demand', foreign_key: :parent_id, inverse_of: :children
  has_many :children, class_name: 'Demand', foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  has_many :demand_transitions, dependent: :destroy
  has_many :demand_blocks, dependent: :destroy
  has_many :stages, -> { distinct }, through: :demand_transitions
  has_many :demand_comments, dependent: :destroy
  has_one :demands_list, inverse_of: :demand, dependent: :restrict_with_error

  has_and_belongs_to_many :team_members, dependent: :destroy, counter_cache: :assignees_count

  validates :project, :created_date, :demand_id, :demand_type, :class_of_service, :assignees_count, presence: true
  validates :demand_id, uniqueness: { scope: :company_id, message: I18n.t('demand.validations.demand_id_unique.message') }

  scope :opened_after_date, ->(date) { kept.story.where('created_date >= :date', date: date.beginning_of_day) }
  scope :finished_in_downstream, -> { kept.story.where('commitment_date IS NOT NULL AND end_date IS NOT NULL') }
  scope :finished_in_upstream, -> { kept.story.where('commitment_date IS NULL AND end_date IS NOT NULL') }
  scope :finished, -> { kept.story.where('demands.end_date IS NOT NULL') }
  scope :finished_with_leadtime, -> { kept.story.where('end_date IS NOT NULL AND leadtime IS NOT NULL') }
  scope :finished_until_date, ->(limit_date) { finished.where('demands.end_date <= :limit_date', limit_date: limit_date) }
  scope :finished_after_date, ->(limit_date) { finished.where('demands.end_date >= :limit_date', limit_date: limit_date.beginning_of_day) }
  scope :finished_with_leadtime_after_date, ->(limit_date) { finished_with_leadtime.where('demands.end_date >= :limit_date', limit_date: limit_date.beginning_of_day) }
  scope :finished_in_month, ->(month, year) { finished.where('EXTRACT(month FROM end_date) = :month AND EXTRACT(year FROM end_date) = :year', month: month, year: year) }
  scope :finished_in_week, ->(week, year) { finished.where('EXTRACT(week FROM end_date) = :week AND EXTRACT(year FROM end_date) = :year', week: week, year: year) }
  scope :not_finished, -> { kept.story.where('end_date IS NULL') }
  scope :in_wip, -> { kept.story.where('demands.commitment_date IS NOT NULL AND demands.end_date IS NULL') }
  scope :to_dates, ->(start_date, end_date) { where('(demands.end_date IS NULL AND demands.created_date BETWEEN :start_date AND :end_date) OR (demands.end_date BETWEEN :start_date AND :end_date)', start_date: start_date.beginning_of_day, end_date: end_date.end_of_day) }

  delegate :name, to: :project, prefix: true

  before_save :compute_and_update_automatic_fields
  after_discard :discard_transitions_and_blocks
  after_undiscard :undiscard_transitions_and_blocks

  def csv_array
    [
      id,
      current_stage&.name,
      demand_id,
      demand_title,
      demand_type,
      class_of_service,
      decimal_value_to_csv(effort_downstream),
      decimal_value_to_csv(effort_upstream),
      created_date&.iso8601,
      commitment_date&.iso8601,
      end_date&.iso8601
    ]
  end

  def update_effort!(update_manual_effort = false)
    return if manual_effort? && !update_manual_effort

    update(effort_downstream: compute_effort_downstream, effort_upstream: compute_effort_upstream)
  end

  def working_time_upstream
    effort_transitions = demand_transitions.kept.upstream_transitions.effort_transitions_to_project(project_id)
    sum_effort(effort_transitions)
  end

  def working_time_downstream
    effort_transitions = demand_transitions.kept.downstream_transitions.effort_transitions_to_project(project_id)
    sum_effort(effort_transitions)
  end

  def blocked_working_time_downstream
    effort_transitions = demand_transitions.kept.downstream_transitions.effort_transitions_to_project(project_id)
    sum_blocked_effort(effort_transitions)
  end

  def blocked_working_time_upstream
    effort_transitions = demand_transitions.kept.upstream_transitions.effort_transitions_to_project(project_id)
    sum_blocked_effort(effort_transitions)
  end

  def downstream_demand?
    commitment_date.present?
  end

  def total_effort
    effort_upstream + effort_downstream
  end

  def current_stage
    demand_transitions.where(last_time_out: nil).order(:last_time_in).last&.stage || demand_transitions.order(:last_time_in)&.last&.stage
  end

  def leadtime_in_days
    return 0.0 if leadtime.blank?

    leadtime.to_f / 1.day
  end

  def partial_leadtime
    return leadtime if leadtime.present?
    return 0 if commitment_date.blank?

    Time.zone.now - commitment_date
  end

  def sum_touch_blocked_time
    sum_blocked_time_for_transitions(demand_transitions.kept.touch_transitions)
  end

  def total_bloked_working_time
    demand_blocks.kept.closed.sum(&:block_duration)
  end

  def stage_at(analysed_date = Time.zone.now)
    transitions_at = demand_transitions.where('last_time_in <= :analysed_date AND (last_time_out IS NULL OR last_time_out >= :analysed_date)', analysed_date: analysed_date)
    transitions_at&.first&.stage
  end

  def aging_when_finished
    return 0 if end_date.blank?

    (end_date - created_date) / 1.day
  end

  private

  def sum_blocked_time_for_transitions(transitions)
    total_blocked = 0
    transitions.each do |transition|
      total_blocked += demand_blocks.kept.closed.active.for_date_interval(transition.last_time_in, transition.last_time_out).sum(&:total_blocked_time)
    end
    total_blocked
  end

  def decimal_value_to_csv(value)
    value.to_f.to_s.gsub('.', I18n.t('number.format.separator'))
  end

  def compute_effort_upstream
    valid_effort = working_time_upstream
    valid_effort *= (project.percentage_effort_to_bugs / 100.0) if bug?
    valid_effort
  end

  def compute_effort_downstream
    valid_effort = working_time_downstream
    valid_effort *= (project.percentage_effort_to_bugs / 100.0) if bug?
    valid_effort
  end

  def sum_effort(effort_transitions)
    total_effort = 0
    effort_transitions.each do |transition|
      stage_config = transition.stage.stage_project_configs.find_by(project: project)
      total_blocked = compute_blocked_effort(stage_config, transition)
      total_effort += ((compute_effort_in_transition(transition, stage_config) * pairing_value(stage_config))) * (1 + (stage_config.management_percentage / 100.0)) - total_blocked
    end
    total_effort
  end

  def compute_blocked_effort(stage_config, transition)
    demand_blocks.kept.closed.active.for_date_interval(transition.last_time_in, transition.last_time_out).sum(:block_duration) * (stage_config.stage_percentage / 100.0)
  end

  def sum_blocked_effort(effort_transitions)
    total_blocked = 0
    effort_transitions.each do |transition|
      total_blocked += demand_blocks.kept.closed.active.for_date_interval(transition.last_time_in, transition.last_time_out).sum(:block_duration)
    end
    total_blocked
  end

  def compute_effort_in_transition(transition, stage_config)
    TimeService.instance.compute_working_hours_for_dates(transition.last_time_in, transition.last_time_out) * (stage_config.stage_percentage / 100.0)
  end

  def pairing_value(stage_config)
    return assignees_count if assignees_count == 1

    pair_count = assignees_count - 1
    1 + (pair_count * (stage_config.pairing_percentage / 100.0))
  end

  def compute_and_update_automatic_fields
    self.leadtime = (end_date - commitment_date if commitment_date.present? && end_date.present?)
    self.company = project.company
  end

  def discard_transitions_and_blocks
    demand_transitions.discard_all
    demand_blocks.discard_all
  end

  def undiscard_transitions_and_blocks
    demand_transitions.undiscard_all
    demand_blocks.undiscard_all
  end
end
