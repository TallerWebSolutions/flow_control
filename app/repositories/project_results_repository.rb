# frozen_string_literal: true

class ProjectResultsRepository
  include Singleton

  def project_results_for_company_month(company, date = Time.zone.today)
    project_result_joins.where('customers.company_id = :company_id AND EXTRACT(MONTH FROM result_date) = :month AND EXTRACT(YEAR FROM result_date) = :year', company_id: company.id, month: date.month, year: date.year)
  end

  def consumed_hours_in_month(company, date = Time.zone.today)
    project_result_joins.where('customers.company_id = :company_id AND EXTRACT(MONTH FROM result_date) = :month AND EXTRACT(YEAR FROM result_date) = :year', company_id: company.id, month: date.month, year: date.year).sum(&:project_delivered_hours)
  end

  def throughput_in_month_for_company(company, date = Time.zone.today)
    project_result_joins.where('customers.company_id = :company_id AND EXTRACT(MONTH FROM result_date) = :month AND EXTRACT(YEAR FROM result_date) = :year', company_id: company.id, month: date.month, year: date.year).sum(&:throughput)
  end

  def bugs_opened_in_month(company, date = Time.zone.today)
    project_result_joins.where('customers.company_id = :company_id AND EXTRACT(MONTH FROM result_date) = :month AND EXTRACT(YEAR FROM result_date) = :year', company_id: company.id, month: date.month, year: date.year).sum(&:qty_bugs_opened)
  end

  def bugs_closed_in_month(company, date = Time.zone.today)
    project_result_joins.where('customers.company_id = :company_id AND EXTRACT(MONTH FROM result_date) = :month AND EXTRACT(YEAR FROM result_date) = :year', company_id: company.id, month: date.month, year: date.year).sum(&:qty_bugs_closed)
  end

  def scope_in_week_for_projects(projects, week, year)
    total_scope = 0
    projects.each do |project|
      known_scope = results_until_week(project, week, year).last&.known_scope
      total_scope += known_scope || project.initial_scope
    end

    total_scope
  end

  def flow_pressure_in_week_for_projects(projects)
    build_hash_data_with_average(projects, :flow_pressure)
  end

  def hours_per_demand_in_time_for_projects(projects)
    hours_upstream_hash = build_hash_data_with_sum(projects, :qty_hours_upstream)
    hours_downstream_hash = build_hash_data_with_sum(projects, :qty_hours_downstream)
    throughput_hash = build_hash_data_with_sum(projects, :throughput)

    hours_per_demand_hash = {}
    throughput_hash.each do |key, value|
      hours_per_demand = (hours_upstream_hash[key] + hours_downstream_hash[key]).to_f / value.to_f
      hours_per_demand_hash[key] = hours_per_demand
    end

    hours_per_demand_hash
  end

  def throughput_for_projects_grouped_per_week(projects)
    build_hash_data_with_sum(projects, :throughput)
  end

  def delivered_until_week(projects, week, year)
    ProjectResult.until_week(week, year).where(project_id: projects.pluck(:id)).sum(:throughput)
  end

  def average_demand_cost_in_week_for_projects(projects)
    cost_in_month = build_hash_data_with_average(projects, :cost_in_month)
    throughput_hash = build_hash_data_with_sum(projects, :throughput)

    average_demand_cost_hash = {}
    throughput_hash.each do |key, value|
      average_cost = (cost_in_month[key] / 4).to_f / value.to_f
      average_demand_cost_hash[key] = average_cost
    end

    average_demand_cost_hash
  end

  def create_empty_project_result(demand, team, result_date)
    project_results = ProjectResult.where(result_date: result_date, project: demand.project)
    return create_new_empty_project_result(demand, team, result_date) if project_results.blank?
    project_results.first
  end

  def create_empty_project_result_using_transition(demand, team)
    first_transition = demand.demand_transitions.order(:last_time_in).first
    return if first_transition.blank?

    previous_result = demand.project_result

    previous_result.remove_demand!(demand) if previous_result.present?

    result_date = define_result_date(demand, first_transition).utc.to_date
    project_result = ProjectResultsRepository.instance.create_empty_project_result(demand, team, result_date)
    project_result.add_demand!(demand)
  end

  def last_manual_entry(project)
    project.project_results.left_outer_joins(demands: :demand_transitions).where(demands: { demand_transitions: { demand_id: nil } }).order(:result_date).last
  end

  private

  def build_hash_data_with_sum(projects, field)
    grouped_project_results(projects).sum(field)
  end

  def build_hash_data_with_average(projects, field)
    grouped_project_results(projects).average(field)
  end

  def grouped_project_results(projects)
    ProjectResult.select("date_trunc('week', result_date) AS week").where(project_id: projects.pluck(:id)).order("date_trunc('week', result_date)").group("date_trunc('week', result_date)")
  end

  def results_until_week(project, week, year)
    project.project_results.where('(EXTRACT(WEEK FROM result_date) <= :week AND EXTRACT(YEAR FROM result_date) <= :year) OR (EXTRACT(YEAR FROM result_date) < :year)', week: week, year: year).order(:result_date)
  end

  def project_result_joins
    ProjectResult.joins(project: [{ product: :customer }])
  end

  def create_new_empty_project_result(demand, team, result_date)
    project_result = demand.project.project_results.where(result_date: result_date)
    return project_result if project_result.present?
    ProjectResult.create(project: demand.project, result_date: result_date, known_scope: 0, throughput: 0, qty_hours_upstream: 0,
                         qty_hours_downstream: 0, qty_hours_bug: 0, qty_bugs_closed: 0, qty_bugs_opened: 0,
                         team: team, flow_pressure: 0, remaining_days: demand.project.remaining_days(result_date),
                         cost_in_month: team.active_cost_for_billable_types([demand.project.project_type]), average_demand_cost: 0,
                         available_hours: team.active_available_hours_for_billable_types([demand.project.project_type]))
  end

  def define_result_date(demand, first_transition)
    end_transition = demand.demand_transitions.joins(:stage).where('stages.end_point = true').last
    commitment_transition = demand.demand_transitions.joins(:stage).where('stages.commitment_point = true').last

    end_transition&.last_time_in || commitment_transition&.last_time_in || first_transition&.last_time_in
  end
end
