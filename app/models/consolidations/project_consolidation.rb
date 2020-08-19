# frozen_string_literal: true

# == Schema Information
#
# Table name: project_consolidations
#
#  id                        :bigint           not null, primary key
#  consolidation_date        :date             not null
#  current_wip               :integer
#  demands_finished_ids      :integer          is an Array
#  demands_finished_in_week  :integer          is an Array
#  demands_ids               :integer          is an Array
#  demands_lead_times        :decimal(, )      is an Array
#  lead_time_in_week         :decimal(, )      is an Array
#  population_end_date       :date
#  population_start_date     :date
#  project_monte_carlo_weeks :integer          is an Array
#  project_weekly_throughput :integer          is an Array
#  team_monte_carlo_weeks    :integer          is an Array
#  team_weekly_throughput    :integer          is an Array
#  wip_limit                 :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  project_id                :integer          not null
#
# Indexes
#
#  index_project_consolidations_on_demands_finished_in_week  (demands_finished_in_week)
#  index_project_consolidations_on_lead_time_in_week         (lead_time_in_week)
#
# Foreign Keys
#
#  fk_rails_09ca62cd76  (project_id => projects.id)
#

module Consolidations
  class ProjectConsolidation < ApplicationRecord
    belongs_to :project

    validates :project, :consolidation_date, presence: true

    def demands_lead_times_average
      return 0 unless demands_lead_time_compact.size.positive?

      Stats::StatisticsService.instance.population_average(demands_lead_time_compact)
    end

    def demands_lead_times_std_dev
      return 0 unless demands_lead_time_compact.count.positive?

      Stats::StatisticsService.instance.standard_deviation(demands_lead_time_compact)
    end

    def lead_time_max
      return 0 unless demands_lead_time_compact.count.positive?

      @lead_time_max ||= demands_lead_time_compact.max
    end

    def lead_time_min
      return 0 unless demands_lead_time_compact.count.positive?

      @lead_time_min ||= demands_lead_time_compact.min
    end

    def total_lead_time_range
      return 0 if lead_time_max.zero? || lead_time_min.zero?

      lead_time_max - lead_time_min
    end

    def histogram_range
      bins = Stats::StatisticsService.instance.leadtime_histogram_hash(demands_lead_time_compact).keys
      return 0 unless bins.size.positive?

      bins.last - bins.first
    end

    def lead_time_histogram_bin_max
      @lead_time_histogram_bin_max ||= lead_time_histogram_bins.max
    end

    def lead_time_histogram_bin_min
      @lead_time_histogram_bin_min ||= lead_time_histogram_bins.min
    end

    def project_monte_carlo_weeks_min
      @project_monte_carlo_weeks_min ||= project_monte_carlo_weeks.min
    end

    def project_monte_carlo_weeks_max
      @project_monte_carlo_weeks_max ||= project_monte_carlo_weeks.max
    end

    def project_monte_carlo_weeks_percentil(percentil = 80)
      return 0 unless project_monte_carlo_weeks.count.positive?

      Stats::StatisticsService.instance.percentile(percentil, project_monte_carlo_weeks)
    end

    def team_monte_carlo_weeks_percentil(percentil = 80)
      return 0 unless team_monte_carlo_weeks.count.positive?

      Stats::StatisticsService.instance.percentile(percentil, team_monte_carlo_weeks)
    end

    def project_monte_carlo_weeks_min_percentage
      return 0 unless project_monte_carlo_weeks.count.positive?

      project_monte_carlo_weeks.count { |x| x <= project_monte_carlo_weeks_min }.to_f / project_monte_carlo_weeks.count
    end

    def team_monte_carlo_weeks_min_percentage
      return 0 unless team_monte_carlo_weeks.count.positive?

      team_monte_carlo_weeks.count { |x| x <= team_monte_carlo_weeks_min }.to_f / team_monte_carlo_weeks.count
    end

    def project_monte_carlo_weeks_std_dev
      return 0 unless project_monte_carlo_weeks.count.positive?

      Stats::StatisticsService.instance.standard_deviation(project_monte_carlo_weeks)
    end

    def team_monte_carlo_weeks_min
      @team_monte_carlo_weeks_min ||= team_monte_carlo_weeks.min
    end

    def team_monte_carlo_weeks_max
      @team_monte_carlo_weeks_max ||= team_monte_carlo_weeks.max
    end

    def team_monte_carlo_weeks_std_dev
      return 0 unless team_monte_carlo_weeks.count.positive?

      Stats::StatisticsService.instance.standard_deviation(team_monte_carlo_weeks)
    end

    def lead_time_p25
      @lead_time_p25 ||= Stats::StatisticsService.instance.percentile(25, demands_lead_time_compact)
    end

    def lead_time_p75
      @lead_time_p75 ||= Stats::StatisticsService.instance.percentile(75, demands_lead_time_compact)
    end

    def interquartile_range
      lead_time_p75 - lead_time_p25
    end

    def population_lead_time(percentile)
      return 0 if demands_lead_times.blank?

      Stats::StatisticsService.instance.percentile(percentile, demands_lead_times)
    end

    def project_little_law_weeks(segment_size = 0)
      return 0 unless project_weekly_throughput.count.positive?

      project.remaining_backlog.to_f / Stats::StatisticsService.instance.population_average(project_weekly_throughput, segment_size)
    end

    def odds_to_deadline_project
      return 0 unless project_monte_carlo_weeks&.count&.positive?

      Stats::StatisticsService.instance.compute_odds_to_deadline(project.remaining_weeks, project_monte_carlo_weeks)
    end

    def odds_to_deadline_team
      return 0 unless team_monte_carlo_weeks.count.positive?

      Stats::StatisticsService.instance.compute_odds_to_deadline(project.remaining_weeks, team_monte_carlo_weeks)
    end

    def customer_happiness
      return 0 unless project_monte_carlo_weeks_percentil.positive?

      project.remaining_weeks((consolidation_date || Time.zone.today).end_of_week).to_f / project_monte_carlo_weeks_percentil
    end

    def lead_time_feature(percentil = 80)
      bugs_lead_time_compact = Demand.where(id: demands_ids).kept.feature.map(&:leadtime).compact
      @lead_time_feature ||= Stats::StatisticsService.instance.percentile(percentil, bugs_lead_time_compact)
    end

    def lead_time_bug(percentil = 80)
      bugs_lead_time_compact = Demand.where(id: demands_ids).kept.bug.map(&:leadtime).compact
      @lead_time_bug ||= Stats::StatisticsService.instance.percentile(percentil, bugs_lead_time_compact)
    end

    def lead_time_chore(percentil = 80)
      bugs_lead_time_compact = Demand.where(id: demands_ids).kept.chore.map(&:leadtime).compact
      @lead_time_chore ||= Stats::StatisticsService.instance.percentile(percentil, bugs_lead_time_compact)
    end

    def lead_time_standard(percentil = 80)
      bugs_lead_time_compact = Demand.where(id: demands_ids).kept.standard.map(&:leadtime).compact
      @lead_time_standard ||= Stats::StatisticsService.instance.percentile(percentil, bugs_lead_time_compact)
    end

    def lead_time_fixed_date(percentil = 80)
      bugs_lead_time_compact = Demand.where(id: demands_ids).kept.fixed_date.map(&:leadtime).compact
      @lead_time_fixed_date ||= Stats::StatisticsService.instance.percentile(percentil, bugs_lead_time_compact)
    end

    def lead_time_expedite(percentil = 80)
      bugs_lead_time_compact = Demand.where(id: demands_ids).kept.expedite.map(&:leadtime).compact
      @lead_time_expedite ||= Stats::StatisticsService.instance.percentile(percentil, bugs_lead_time_compact)
    end

    private

    def demands_lead_time_compact
      @demands_lead_time_compact ||= demands_lead_times.compact
    end

    def lead_time_histogram_bins
      lead_time_histogram_data = Stats::StatisticsService.instance.leadtime_histogram_hash(demands_lead_time_compact)
      @lead_time_histogram_bins = lead_time_histogram_data.keys
    end
  end
end