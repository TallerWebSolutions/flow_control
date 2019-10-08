# frozen_string_literal: true

class DemandsRepository
  include Singleton

  def known_scope_to_date(demands_ids, analysed_date)
    demands_list_data(demands_ids).opened_before_date(analysed_date)
  end

  def remaining_backlog_to_date(demands_ids, analysed_date)
    demands = demands_list_data(demands_ids).opened_before_date(analysed_date)

    demands.where('(end_date IS NULL OR end_date > :analysed_date) AND (commitment_date IS NULL OR commitment_date > :analysed_date)', analysed_date: analysed_date).count
  end

  def committed_demands_by_project_and_week(projects, week, year)
    demands_stories_to_projects(projects).where('EXTRACT(WEEK FROM commitment_date) = :week AND EXTRACT(YEAR FROM commitment_date) = :year', week: week, year: year)
  end

  def demands_delivered_grouped_by_projects_to_period(projects, start_period, end_period)
    throughput_to_projects_and_period(projects, start_period, end_period).group_by(&:project_name)
  end

  def throughput_to_projects_and_period(projects, start_period, end_period)
    demands_stories_to_projects(projects).to_end_dates(start_period, end_period)
  end

  def throughput_to_products_team_and_period(products, team, start_period, end_period)
    Demand.kept.where(product_id: products, team: team).to_end_dates(start_period, end_period)
  end

  def created_to_projects_and_period(projects, start_period, end_period)
    demands_stories_to_projects(projects).where('created_date BETWEEN :start_period AND :end_period', start_period: start_period, end_period: end_period)
  end

  def effort_upstream_grouped_by_month(projects, start_date, end_date)
    effort_upstream_hash = {}
    Demand.kept
          .select('EXTRACT(YEAR from end_date) AS year, EXTRACT(MONTH from end_date) AS month, SUM(effort_upstream) AS computed_sum_effort')
          .where(project_id: projects.map(&:id))
          .to_end_dates(start_date, end_date)
          .order('year, month')
          .group('year, month')
          .map { |group_sum| effort_upstream_hash[[group_sum.year, group_sum.month]] = group_sum.computed_sum_effort.to_f }
    effort_upstream_hash
  end

  def grouped_by_effort_downstream_per_month(projects, start_date, end_date)
    effort_downstream_hash = {}
    Demand.kept
          .select('EXTRACT(YEAR from end_date) AS year, EXTRACT(MONTH from end_date) AS month, SUM(effort_downstream) AS computed_sum_effort')
          .where(project_id: projects.map(&:id))
          .to_end_dates(start_date, end_date)
          .order('year, month')
          .group('year, month')
          .map { |group_sum| effort_downstream_hash[[group_sum.year, group_sum.month]] = group_sum.computed_sum_effort.to_f }
    effort_downstream_hash
  end

  def delivered_hours_in_month_for_projects(projects, date = Time.zone.today)
    demands_for_projects_finished_in_period(projects, date.beginning_of_month, date.end_of_month).sum(:effort_downstream) + demands_for_projects_finished_in_period(projects, date.beginning_of_month, date.end_of_month).sum(:effort_upstream)
  end

  def upstream_throughput_in_month_for_projects(projects, date = Time.zone.today)
    demands_for_projects_finished_in_period(projects, date.beginning_of_month, date.end_of_month).finished_in_upstream
  end

  def downstream_throughput_in_month_for_projects(projects, date = Time.zone.today)
    demands_for_projects_finished_in_period(projects, date.beginning_of_month, date.end_of_month).finished_in_downstream
  end

  def demands_delivered_for_period(demands, start_period, end_period)
    Demand.kept.where(id: demands.map(&:id)).to_end_dates(start_period, end_period)
  end

  def demands_delivered_for_period_accumulated(demands, upper_date_limit)
    Demand.kept.where(id: demands.map(&:id)).where('demands.end_date <= :upper_limit', upper_limit: upper_date_limit)
  end

  def cumulative_flow_for_date(demands_ids, start_date, end_date, stream)
    demands = Demand.joins(demand_transitions: :stage)
                    .where(id: demands_ids)
                    .where('demands.discarded_at IS NULL OR demands.discarded_at > :end_date', end_date: end_date)
                    .where('(demands.end_date IS NULL OR demands.end_date >= :start_date)', start_date: start_date)
                    .where('stages.stage_stream = :stream', stream: Stage.stage_streams[stream])

    stages_id = demands.select('stages.id AS stage_id').map(&:stage_id).uniq
    stages = Stage.where(id: stages_id)

    build_cumulative_stage_hash(end_date, demands, stages)
  end

  def discarded_demands_to_projects(projects)
    Demand.where(project_id: projects.map(&:id)).where('discarded_at IS NOT NULL').order(discarded_at: :desc)
  end

  private

  def demands_list_data(demands_ids)
    Demand.where(id: demands_ids)
  end

  def build_cumulative_stage_hash(analysed_date, demands, stages)
    cumulative_hash = {}
    stages.order('stages.order DESC').each do |stage|
      stage_demands_count = demands.where('demand_transitions.last_time_in <= :limit_date', limit_date: analysed_date).where(stages: { id: stage.id }).uniq.count
      cumulative_hash[stage.name] = stage_demands_count
    end

    cumulative_hash.to_a.reverse.to_h
  end

  def demands_stories_to_projects(projects)
    Demand.kept.where(project_id: projects.map(&:id))
  end

  def demands_for_projects_finished_in_period(projects, start_period, end_period)
    Demand.kept.where(project_id: projects).to_end_dates(start_period, end_period)
  end
end
