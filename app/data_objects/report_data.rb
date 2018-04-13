# frozen_string_literal: true

class ReportData
  attr_reader :projects, :weeks, :ideal, :current, :scope, :flow_pressure_data

  def initialize(projects)
    @projects = projects
    @weeks = projects_weeks
    @ideal = []
    @current = []
    @scope = []
    @flow_pressure_data = []
    mount_flow_pressure_array
    mount_burnup_data
  end

  def projects_names
    projects.map(&:full_name)
  end

  def hours_per_demand_per_week
    weekly_data = ProjectResultsRepository.instance.hours_per_demand_in_time_for_projects(@projects)

    result_data = []
    @weeks.each do |week_year|
      break unless add_data_to_chart?(week_year)
      keys_matching = weekly_data.keys.select { |key| date_hash_matches?(key, week_year) }
      result_data << (weekly_data[keys_matching.first] || 0)
    end
    result_data
  end

  def throughput_per_week
    upstream_th_weekly_data = ProjectResultsRepository.instance.throughput_for_projects_grouped_per_week(@projects, :upstream)
    downstream_th_weekly_data = ProjectResultsRepository.instance.throughput_for_projects_grouped_per_week(@projects, :downstream)

    throughput_chart_data(downstream_th_weekly_data, upstream_th_weekly_data)
  end

  def delivered_vs_remaining
    [{ name: I18n.t('projects.show.delivered_scope'), data: [@projects.sum(&:total_throughput)] }, { name: I18n.t('projects.show.scope_gap'), data: [@projects.sum(&:total_gap)] }]
  end

  def deadline
    min_date = @projects.minimum(:start_date)
    max_date = @projects.maximum(:end_date)
    passed_time = (Time.zone.today - min_date).to_i + 1
    remaining_days = (max_date - Time.zone.today).to_i + 1
    [{ name: I18n.t('projects.index.total_remaining_days'), data: [remaining_days] }, { name: I18n.t('projects.index.passed_time'), data: [passed_time], color: '#F45830' }]
  end

  def average_demand_cost
    weekly_data = ProjectResultsRepository.instance.average_demand_cost_in_week_for_projects(@projects)

    result_data = []
    @weeks.each do |week_year|
      break unless add_data_to_chart?(week_year)
      keys_matching = weekly_data.keys.select { |key| date_hash_matches?(key, week_year) }
      result_data << (weekly_data[keys_matching.first] || 0)
    end
    result_data
  end

  def dates_and_odds
    project = @projects.first
    monte_carlo_data = Stats::StatisticsService.instance.run_montecarlo(project.demands.count,
                                                                        ProjectsRepository.instance.leadtime_per_week([project]).values,
                                                                        ProjectsRepository.instance.throughput_per_week([project]).values,
                                                                        500)

    mount_deadline_odds_data(monte_carlo_data, project).sort_by { |keys, _values| keys }.to_h
  end

  def montecarlo_dates
    project = @projects.first
    Stats::StatisticsService.instance.run_montecarlo(project.demands.count,
                                                     ProjectsRepository.instance.leadtime_per_week([project]).values,
                                                     ProjectsRepository.instance.throughput_per_week([project]).values,
                                                     500)
  end

  private

  def mount_deadline_odds_data(monte_carlo_data, project)
    all_montecarlo_dates = monte_carlo_data.monte_carlo_date_hash.keys
    most_likely_montecarlo_date = all_montecarlo_dates.first
    most_likely_montecarlo_odd = monte_carlo_data.monte_carlo_date_hash.values.first

    project_deadline = project.end_date
    project_deadline_odd = monte_carlo_data.monte_carlo_date_hash[project_deadline]
    project_deadline_odd = most_likely_montecarlo_odd if project_deadline >= most_likely_montecarlo_date

    nearest_montecarlo_date = CollectionsService.find_nearest(all_montecarlo_dates, project_deadline)
    nearest_montecarlo_odd = monte_carlo_data.monte_carlo_date_hash[project_deadline]

    montecarlo_dates_hash = { project_deadline => [project_deadline_odd], most_likely_montecarlo_date => [most_likely_montecarlo_odd] }
    montecarlo_dates_hash.merge(nearest_montecarlo_date => nearest_montecarlo_odd)

    montecarlo_dates_hash
  end

  def throughput_chart_data(downstream_th_weekly_data, upstream_th_weekly_data)
    upstream_result_data = []
    downstream_result_data = []
    @weeks.each do |week_year|
      break unless add_data_to_chart?(week_year)
      upstream_keys_matching = upstream_th_weekly_data.keys.select { |key| date_hash_matches?(key, week_year) }
      upstream_result_data << (upstream_th_weekly_data[upstream_keys_matching.first] || 0)

      downstream_keys_matching = downstream_th_weekly_data.keys.select { |key| date_hash_matches?(key, week_year) }
      downstream_result_data << (downstream_th_weekly_data[downstream_keys_matching.first] || 0)
    end
    [{ name: I18n.t('projects.charts.throughput_per_week.stage_stream.upstream'), data: upstream_result_data }, { name: I18n.t('projects.charts.throughput_per_week.stage_stream.downstream'), data: downstream_result_data }]
  end

  def date_hash_matches?(key, week_year)
    key.to_date.cweek == week_year[0] && key.to_date.cwyear == week_year[1]
  end

  def projects_weeks
    min_date = projects.active.minimum(:start_date)
    max_date = projects.active.maximum(:end_date)
    array_of_weeks = []

    return [] if min_date.blank? || max_date.blank?

    while min_date <= max_date
      array_of_weeks << [min_date.cweek, min_date.cwyear]
      min_date += 7.days
    end

    array_of_weeks
  end

  def mount_burnup_data
    @weeks.each_with_index do |week_year, index|
      @ideal << ideal_burn(index)
      week = week_year[0]
      year = week_year[1]
      upstream_total_delivered = throughput_to_projects_and_stream(week, year, projects, :throughput_upstream)
      downstream_total_delivered = throughput_to_projects_and_stream(week, year, projects, :throughput_downstream)
      @current << upstream_total_delivered + downstream_total_delivered if add_data_to_chart?(week_year)
      @scope << ProjectResultsRepository.instance.scope_in_week_for_projects(projects, week, year)
    end
  end

  def throughput_to_projects_and_stream(week, year, projects, throughput_field)
    ProjectResult.until_week(week, year).where(project_id: projects.pluck(:id)).sum(throughput_field)
  end

  def ideal_burn(index)
    (@projects.sum(&:last_week_scope).to_f / @weeks.count.to_f) * (index + 1)
  end

  def mount_flow_pressure_array
    weekly_data = ProjectResultsRepository.instance.flow_pressure_in_week_for_projects(@projects)

    @weeks.each do |week_year|
      begining_of_week = Date.commercial(week_year[1], week_year[0], 1)
      keys_matching = weekly_data.keys.select { |key| date_hash_matches?(key, week_year) }
      add_actual_or_projected_data(begining_of_week, keys_matching, weekly_data)
    end
  end

  def add_actual_or_projected_data(begining_of_week, keys_matching, weekly_data)
    @flow_pressure_data << (weekly_data[keys_matching.first].to_f || 0.0) if keys_matching.present? || begining_of_week <= Time.zone.today
    @flow_pressure_data << @projects.sum { |p| p.flow_pressure(begining_of_week) } / @projects.count.to_f if begining_of_week.future?
  end

  def add_data_to_chart?(week_year)
    week_year[1] < Time.zone.today.cwyear || (week_year[0] <= Time.zone.today.cweek && week_year[1] <= Time.zone.today.cwyear)
  end
end
