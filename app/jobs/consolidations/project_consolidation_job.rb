# frozen_string_literal: true

module Consolidations
  class ProjectConsolidationJob < ApplicationJob
    queue_as :consolidations

    def perform(project, user = nil, project_url = nil)
      started_time = Time.zone.now

      min_date = project.start_date
      start_date = project.start_date
      end_date = [project.end_date, Time.zone.today.end_of_week].min
      team = project.team
      min_date_team = [team.demands.finished_with_leadtime.map(&:end_date).compact.min, 20.weeks.ago.beginning_of_week].compact.max

      while start_date <= end_date
        beginning_of_week = start_date.beginning_of_week
        end_of_week = start_date.end_of_week

        demands = project.demands.kept.where('demands.created_date <= :analysed_date', analysed_date: end_of_week)
        demands_finished = demands.finished_with_leadtime.where('demands.end_date <= :analysed_date', analysed_date: end_of_week).order(end_date: :asc)
        demands_finished_in_week = demands.finished_with_leadtime.to_end_dates(beginning_of_week, end_of_week).order(end_date: :asc)

        x_axis = TimeService.instance.weeks_between_of(min_date.end_of_week, start_date.end_of_week)
        x_axis_team = TimeService.instance.weeks_between_of(min_date_team.end_of_week, start_date.end_of_week)

        project_work_item_flow_information = Flow::WorkItemFlowInformations.new(project.demands.kept, project.initial_scope, x_axis.length, x_axis.last)
        team_work_item_flow_information = Flow::WorkItemFlowInformations.new(team.demands.kept, team.projects.map(&:initial_scope).compact.sum, x_axis.length, x_axis.last)

        x_axis.each_with_index { |analysed_date, distribution_index| project_work_item_flow_information.work_items_flow_behaviour(x_axis.first, analysed_date, distribution_index, true) }

        x_axis_team.each_with_index { |analysed_date, distribution_index| team_work_item_flow_information.work_items_flow_behaviour(x_axis_team.first, analysed_date, distribution_index, true) }

        project_based_montecarlo_durations = Stats::StatisticsService.instance.run_montecarlo(project.remaining_work(end_of_week), project_work_item_flow_information.throughput_array_for_monte_carlo.last(10), 500)
        team_based_montecarlo_durations = compute_team_monte_carlo_weeks(end_of_week, project, team_work_item_flow_information.throughput_per_period.last(20))

        consolidation = ProjectConsolidation.find_or_initialize_by(project: project, consolidation_date: end_of_week)
        consolidation.update(population_start_date: demands.minimum(:created_date),
                             population_end_date: demands.maximum(:end_date),
                             wip_limit: project.max_work_in_progress,
                             current_wip: compute_current_wip(beginning_of_week, end_of_week, demands),
                             demands_ids: demands.map(&:id),
                             demands_finished_ids: demands_finished.map(&:id),
                             demands_lead_times: demands_finished.map(&:leadtime),
                             demands_finished_in_week: demands_finished_in_week.map(&:id),
                             lead_time_in_week: demands_finished_in_week.map(&:leadtime),
                             project_weekly_throughput: project_work_item_flow_information.throughput_per_period,
                             team_weekly_throughput: team_work_item_flow_information.throughput_per_period,
                             project_monte_carlo_weeks: project_based_montecarlo_durations,
                             team_monte_carlo_weeks: team_based_montecarlo_durations)

        start_date += 1.week
      end

      finished_time = Time.zone.now

      UserNotifierMailer.async_activity_finished(user.email, user.full_name, ProjectConsolidation.model_name.human.downcase, project.name, started_time, finished_time, project_url).deliver if user.present? && project_url.present?
    end

    private

    def compute_current_wip(beginning_of_week, end_of_week, demands)
      wip_per_day = []
      (beginning_of_week.to_date..end_of_week.to_date).each do |day|
        wip_per_day << demands.where('(demands.commitment_date <= :end_date AND demands.end_date IS NULL) OR (commitment_date <= :start_date AND end_date > :end_date)', start_date: day.beginning_of_day, end_date: day.end_of_day).count
      end

      average_wip_per_day_to_week = 0
      average_wip_per_day_to_week = wip_per_day.compact.sum / wip_per_day.compact.count if wip_per_day.compact.size.positive?
      average_wip_per_day_to_week
    end

    def compute_team_monte_carlo_weeks(limit_date, project, team_throughput_data)
      team = project.team

      project_wip = project.max_work_in_progress
      team_wip = team.max_work_in_progress
      project_share_in_flow = 1
      project_share_in_flow = (project_wip.to_f / team_wip.to_f) if team_wip.positive? && project_wip.positive?

      project_share_team_throughput_data = team_throughput_data.map { |throughput| throughput * project_share_in_flow }
      Stats::StatisticsService.instance.run_montecarlo(project.remaining_work(limit_date), project_share_team_throughput_data, 500)
    end
  end
end