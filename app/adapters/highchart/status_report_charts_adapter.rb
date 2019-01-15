# frozen_string_literal: true

module Highchart
  class StatusReportChartsAdapter < HighchartAdapter
    attr_reader :hours_burnup_per_week_data, :hours_burnup_per_month_data, :dates_to_montecarlo_duration, :confidence_95_duration, :confidence_80_duration, :confidence_60_duration

    def initialize(projects, period)
      super(projects, period)
      montecarlo_durations = Stats::StatisticsService.instance.run_montecarlo(@all_projects.active.sum(&:backlog_remaining), gather_throughput_data, 500)
      build_montecarlo_perecentage_confidences(montecarlo_durations)
      build_dates_to_montecarlo_duration

      @hours_burnup_per_week_data = Highchart::BurnupChartsAdapter.new(@all_projects_weeks, build_hours_scope_data_per_week, build_hours_throughput_data_week)
      @hours_burnup_per_month_data = Highchart::BurnupChartsAdapter.new(@all_projects_months, build_hours_scope_data_per_month, build_hours_throughput_data_month)
    end

    def throughput_per_week
      throughput_chart_data
    end

    def delivered_vs_remaining
      [{ name: I18n.t('projects.show.delivered_demands.opened_in_period'), data: [@all_projects.sum { |project| project.demands.opened_after_date(charts_data_bottom_limit_date).count }] }, { name: I18n.t('projects.show.delivered_demands.delivered'), data: [@all_projects.sum { |project| project.demands.finished_after_date(charts_data_bottom_limit_date).count }] }, { name: I18n.t('projects.show.scope_gap'), data: [@all_projects.sum(&:backlog_remaining)] }]
    end

    def deadline
      min_date = @all_projects.minimum(:start_date)
      max_date = @all_projects.maximum(:end_date)
      return [] if min_date.blank?

      passed_time = (Time.zone.today - min_date).to_i + 1
      remaining_days = (max_date - Time.zone.today).to_i + 1
      [{ name: I18n.t('projects.index.total_remaining_days'), data: [remaining_days] }, { name: I18n.t('projects.index.passed_time'), data: [passed_time], color: '#F45830' }]
    end

    def deadline_vs_montecarlo_durations
      return [] if @all_projects.blank?

      max_date = @all_projects.maximum(:end_date)
      remaining_weeks = ((max_date - Time.zone.today).to_i / 7) + 1

      [
        { name: I18n.t('projects.index.total_remaining_weeks'), data: [remaining_weeks] },
        { name: I18n.t('projects.charts.deadline_vs_montecarlo_durations.confidence_95'), data: [@confidence_95_duration] },
        { name: I18n.t('projects.charts.deadline_vs_montecarlo_durations.confidence_80'), data: [@confidence_80_duration] },
        { name: I18n.t('projects.charts.deadline_vs_montecarlo_durations.confidence_60'), data: [@confidence_60_duration] }
      ]
    end

    def hours_per_stage
      hours_per_stage_distribution = ProjectsRepository.instance.hours_per_stage(@all_projects, charts_data_bottom_limit_date)
      hours_per_stage_chart_hash = {}
      hours_per_stage_chart_hash[:xcategories] = hours_per_stage_distribution.map { |hours_per_stage_array| hours_per_stage_array[0] }
      hours_per_stage_chart_hash[:hours_per_stage] = hours_per_stage_distribution.map { |hours_per_stage_array| hours_per_stage_array[2] / 3600 }
      hours_per_stage_chart_hash
    end

    private

    def build_montecarlo_perecentage_confidences(montecarlo_durations)
      @confidence_95_duration = Stats::StatisticsService.instance.percentile(95, montecarlo_durations)
      @confidence_80_duration = Stats::StatisticsService.instance.percentile(80, montecarlo_durations)
      @confidence_60_duration = Stats::StatisticsService.instance.percentile(60, montecarlo_durations)
    end

    def build_dates_to_montecarlo_duration
      @dates_to_montecarlo_duration = []
      active_projects = @all_projects.active
      return if active_projects.blank?

      @dates_to_montecarlo_duration << { name: I18n.t('projects.charts.montecarlo_dates.project_date'), date: active_projects.maximum(:end_date), color: '#1E8449' }
      @dates_to_montecarlo_duration << { name: I18n.t('projects.charts.montecarlo_dates.confidence_95'), date: TimeService.instance.add_weeks_to_today(@confidence_95_duration), color: '#B7950B' }
      @dates_to_montecarlo_duration << { name: I18n.t('projects.charts.montecarlo_dates.confidence_80'), date: TimeService.instance.add_weeks_to_today(@confidence_80_duration), color: '#F4D03F' }
      @dates_to_montecarlo_duration << { name: I18n.t('projects.charts.montecarlo_dates.confidence_60'), date: TimeService.instance.add_weeks_to_today(@confidence_60_duration), color: '#CB4335' }
    end

    def gather_throughput_data
      return [] if @all_projects.blank?

      build_throughput_array.last(15)
    end

    def build_throughput_array
      throughput_data_array = ProjectsRepository.instance.throughput_per_week(@all_projects, @all_projects.minimum(:start_date)).values
      throughput_data_array = ProjectsRepository.instance.throughput_per_week(@all_projects.first.product.projects, @all_projects.first.product.projects.minimum(:start_date)).values if throughput_data_array.size < 15 && @all_projects.count == 1
      throughput_data_array
    end

    def build_hours_scope_data_per_week
      scope_per_week = []
      @all_projects_weeks.each { |_week_year| scope_per_week << @all_projects.sum(:qty_hours).to_f }
      scope_per_week
    end

    def build_hours_scope_data_per_month
      scope_per_month = []
      @all_projects_months.each { |_month_year| scope_per_month << @all_projects.sum(:qty_hours).to_f }
      scope_per_month
    end

    def build_hours_throughput_data_week
      throughput_per_week = []
      @all_projects_weeks.each do |date|
        upstream_total_delivered = DemandsRepository.instance.delivered_until_date_to_projects_in_upstream(@all_projects, date.to_date).sum(&:total_effort)
        downstream_total_delivered = DemandsRepository.instance.delivered_until_date_to_projects_in_downstream(@all_projects, date.to_date).sum(&:total_effort)
        throughput_per_week << upstream_total_delivered + downstream_total_delivered if add_data_to_chart?(date.to_date)
      end
      throughput_per_week
    end

    def build_hours_throughput_data_month
      throughput_per_month = []
      @all_projects_months.each do |date|
        upstream_total_delivered = DemandsRepository.instance.delivered_until_date_to_projects_in_upstream(all_projects, date).sum(&:total_effort)
        downstream_total_delivered = DemandsRepository.instance.delivered_until_date_to_projects_in_downstream(all_projects, date).sum(&:total_effort)

        throughput_per_month << upstream_total_delivered + downstream_total_delivered if add_month_data_to_chart?(date)
      end
      throughput_per_month
    end
  end
end
