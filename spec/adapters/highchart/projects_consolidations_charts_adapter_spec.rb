# frozen_string_literal: true

RSpec.describe Highchart::ProjectsConsolidationsChartsAdapter, type: :service do
  before { travel_to Time.zone.local(2018, 2, 20, 10, 0, 0) }

  after { travel_back }

  describe '#lead_time_data_range_evolution' do
    let(:company) { Fabricate :company }
    let(:customer) { Fabricate :customer, company: company }

    context 'having projects' do
      let!(:first_project) { Fabricate :project, customers: [customer], status: :maintenance, start_date: 3.months.ago, end_date: 2.months.ago, qty_hours: 1000, initial_scope: 95, value: 200.0 }
      let!(:second_project) { Fabricate :project, customers: [customer], status: :executing, start_date: 3.months.ago, end_date: Time.zone.today, qty_hours: 500, initial_scope: 40, value: 3_453_220.0 }

      let!(:project_consolidation) { Fabricate :project_consolidation, consolidation_date: 65.days.ago, project: first_project }
      let!(:other_project_consolidation) { Fabricate :project_consolidation, consolidation_date: 34.days.ago, project: second_project }
      let!(:fields_nil_project_consolidation) { Fabricate :project_consolidation, consolidation_date: 34.days.ago, project: first_project, demands_lead_times: [] }

      context 'passing no date filter' do
        it 'builds the data structure for scope_data_evolution' do
          consolidation_data = described_class.new(ProjectConsolidation.all, first_project.start_date, second_project.end_date)

          expect(consolidation_data.lead_time_data_range_evolution[:x_axis]).to eq [Date.new(2017, 12, 17), Date.new(2018, 1, 17)]
          expect(consolidation_data.lead_time_data_range_evolution[:y_axis][0][:name]).to eq I18n.t('charts.lead_time_data_range_evolution.total_range')
          expect(consolidation_data.lead_time_data_range_evolution[:y_axis][0][:data]).to eq [6.481481481481482e-05, 6.481481481481482e-05]

          expect(consolidation_data.lead_time_data_range_evolution[:y_axis][1][:name]).to eq I18n.t('charts.lead_time_data_range_evolution.total_range_max')
          expect(consolidation_data.lead_time_data_range_evolution[:y_axis][1][:data]).to eq [7.87037037037037e-05, 7.87037037037037e-05]

          expect(consolidation_data.lead_time_data_range_evolution[:y_axis][2][:name]).to eq I18n.t('charts.lead_time_data_range_evolution.total_range_min')
          expect(consolidation_data.lead_time_data_range_evolution[:y_axis][2][:data]).to eq [1.3888888888888888e-05, 1.3888888888888888e-05]
        end
      end
    end
  end

  describe '#lead_time_histogram_data_range_evolution' do
    let(:company) { Fabricate :company }
    let(:customer) { Fabricate :customer, company: company }

    context 'having projects' do
      let!(:first_project) { Fabricate :project, customers: [customer], status: :maintenance, start_date: 3.months.ago, end_date: 2.months.ago, qty_hours: 1000, initial_scope: 95, value: 200.0 }
      let!(:second_project) { Fabricate :project, customers: [customer], status: :executing, start_date: 3.months.ago, end_date: 1.month.ago, qty_hours: 500, initial_scope: 40, value: 3_453_220.0 }

      let!(:project_consolidation) { Fabricate :project_consolidation, consolidation_date: 65.days.ago, project: first_project }
      let!(:other_project_consolidation) { Fabricate :project_consolidation, consolidation_date: 34.days.ago, project: second_project }

      context 'with data' do
        it 'builds the data structure for scope_data_evolution' do
          consolidation_data = described_class.new(ProjectConsolidation.all, first_project.start_date, first_project.end_date)

          expect(consolidation_data.lead_time_histogram_data_range_evolution[:x_axis]).to eq [65.days.ago.to_date]
          expect(consolidation_data.lead_time_histogram_data_range_evolution[:y_axis][0][:name]).to eq I18n.t('charts.lead_time_histogram_data_range_evolution.total_range')
          expect(consolidation_data.lead_time_histogram_data_range_evolution[:y_axis][0][:data]).to eq [3.240740740740741e-05]

          expect(consolidation_data.lead_time_histogram_data_range_evolution[:y_axis][1][:name]).to eq I18n.t('charts.lead_time_histogram_data_range_evolution.total_range_max')
          expect(consolidation_data.lead_time_histogram_data_range_evolution[:y_axis][1][:data]).to eq [6.25e-05]

          expect(consolidation_data.lead_time_histogram_data_range_evolution[:y_axis][2][:name]).to eq I18n.t('charts.lead_time_histogram_data_range_evolution.total_range_min')
          expect(consolidation_data.lead_time_histogram_data_range_evolution[:y_axis][2][:data]).to eq [3.0092592592592593e-05]
        end
      end
    end
  end

  describe '#lead_time_interquartile_data_range_evolution' do
    let(:company) { Fabricate :company }
    let(:customer) { Fabricate :customer, company: company }

    context 'having projects' do
      let!(:first_project) { Fabricate :project, customers: [customer], status: :maintenance, start_date: 3.months.ago, end_date: 2.months.ago, qty_hours: 1000, initial_scope: 95, value: 200.0 }
      let!(:second_project) { Fabricate :project, customers: [customer], status: :executing, start_date: 3.months.ago, end_date: 1.month.ago, qty_hours: 500, initial_scope: 40, value: 3_453_220.0 }

      let!(:project_consolidation) { Fabricate :project_consolidation, consolidation_date: 65.days.ago, project: first_project }
      let!(:other_project_consolidation) { Fabricate :project_consolidation, consolidation_date: 34.days.ago, project: second_project }

      context 'passing no date filter' do
        it 'builds the data structure for scope_data_evolution' do
          consolidation_data = described_class.new(ProjectConsolidation.all, first_project.start_date, first_project.end_date)

          expect(consolidation_data.lead_time_interquartile_data_range_evolution[:x_axis]).to eq [65.days.ago.to_date]
          expect(consolidation_data.lead_time_interquartile_data_range_evolution[:y_axis][0][:name]).to eq I18n.t('charts.lead_time_interquartile_data_range_evolution.total_range')
          expect(consolidation_data.lead_time_interquartile_data_range_evolution[:y_axis][0][:data]).to eq [3.240740740740741e-05]

          expect(consolidation_data.lead_time_interquartile_data_range_evolution[:y_axis][1][:name]).to eq I18n.t('charts.lead_time_interquartile_data_range_evolution.percentile_25')
          expect(consolidation_data.lead_time_interquartile_data_range_evolution[:y_axis][1][:data]).to eq [3.2986111111111115e-05]

          expect(consolidation_data.lead_time_interquartile_data_range_evolution[:y_axis][2][:name]).to eq I18n.t('charts.lead_time_interquartile_data_range_evolution.percentile_75')
          expect(consolidation_data.lead_time_interquartile_data_range_evolution[:y_axis][2][:data]).to eq [6.539351851851852e-05]
        end
      end
    end
  end
end
