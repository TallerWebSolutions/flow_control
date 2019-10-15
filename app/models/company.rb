# frozen_string_literal: true

# == Schema Information
#
# Table name: companies
#
#  abbreviation    :string           not null, indexed
#  api_token       :string           not null, indexed
#  created_at      :datetime         not null
#  customers_count :integer          default(0)
#  id              :bigint(8)        not null, primary key
#  name            :string           not null
#  slug            :string           indexed
#  updated_at      :datetime         not null
#

class Company < ApplicationRecord
  extend FriendlyId
  friendly_id :abbreviation, use: :slugged

  has_and_belongs_to_many :users

  has_many :financial_informations, dependent: :restrict_with_error
  has_many :customers, dependent: :restrict_with_error
  has_many :products, through: :customers
  has_many :projects, counter_cache: true, dependent: :restrict_with_error
  has_many :jira_project_configs, through: :projects
  has_many :jira_product_configs, through: :products
  has_many :demands, through: :projects
  has_many :teams, dependent: :restrict_with_error
  has_many :team_members, dependent: :destroy
  has_many :memberships, through: :team_members
  has_many :stages, dependent: :restrict_with_error
  has_many :jira_accounts, class_name: 'Jira::JiraAccount', dependent: :destroy, inverse_of: :company
  has_many :team_resources, dependent: :destroy

  has_one :company_settings, dependent: :destroy

  validates :name, :abbreviation, presence: true

  before_save :generate_token

  def add_user(user)
    return if users.include?(user)

    users << user
  end

  def active_projects_count
    customers.sum { |p| p.active_projects.count }
  end

  def waiting_projects_count
    customers.sum { |p| p.waiting_projects.count }
  end

  def projects_count
    customers.sum(&:projects_count)
  end

  def products_count
    customers.sum(&:products_count)
  end

  def current_cost_per_hour
    finance = financial_informations.where('finances_date <= current_date').order(finances_date: :desc).first
    return 0 if finance.blank?
    return compute_current_cost_per_hour(finance) if consumed_hours_in_month.positive?

    finance.expenses_total
  end

  def current_hours_per_demand
    return consumed_hours_in_month.to_f / current_month_throughput if current_month_throughput.positive?

    consumed_hours_in_month
  end

  def current_month_throughput
    @current_month_throughput ||= (DemandsRepository.instance.upstream_throughput_in_month_for_projects(projects).count + DemandsRepository.instance.downstream_throughput_in_month_for_projects(projects).count)
  end

  def last_week_scope
    customers.joins(customers_projects: :project).includes(customers_projects: :project).includes(:projects).sum(&:last_week_scope)
  end

  def avg_hours_per_demand
    customers.sum(&:avg_hours_per_demand) / customers_count.to_f
  end

  def consumed_hours_in_month(date = Time.zone.today)
    @consumed_hours_in_month ||= DemandsRepository.instance.delivered_hours_in_month_for_projects(projects, date)
  end

  def throughput_in_month(date = Time.zone.today)
    DemandsRepository.instance.downstream_throughput_in_month_for_projects(projects, date) + DemandsRepository.instance.upstream_throughput_in_month_for_projects(projects, date)
  end

  def top_three_flow_pressure
    projects.running.sort_by(&:flow_pressure).reverse.first(3)
  end

  def top_three_throughput(date = Time.zone.today)
    projects.running.sort_by { |project| project.total_throughput_for(date) }.reverse.first(3)
  end

  def next_starting_project
    projects.waiting.order(:start_date).first
  end

  def next_finishing_project
    projects.running.order(:end_date).first
  end

  def demands_delivered_last_week
    return [] if projects.blank?

    DemandsRepository.instance.throughput_to_projects_and_period(projects, projects.map(&:start_date).min.beginning_of_week, 1.week.ago.end_of_week)
  end

  def total_active_hours
    projects.active.sum(:qty_hours)
  end

  def total_active_consumed_hours
    projects.active.sum(&:total_hours_consumed)
  end

  def total_available_hours
    total_available = 0
    teams.sum { |team| total_available += team.active_monthly_available_hours_for_billable_types(projects.pluck(:project_type).uniq) }
    total_available
  end

  private

  def compute_current_cost_per_hour(finance)
    finance.expenses_total / consumed_hours_in_month
  end

  def generate_token
    self.api_token = loop do
      random_token = SecureRandom.urlsafe_base64(nil, false)
      break random_token unless self.class.exists?(api_token: random_token)
    end
  end
end
