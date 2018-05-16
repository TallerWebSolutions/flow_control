# frozen_string_literal: true

RSpec.describe ReportData, type: :data_object do
  context 'having projects' do
    let(:first_project) { Fabricate :project, status: :executing, start_date: Time.zone.parse('2018-02-20'), end_date: Time.zone.parse('2018-03-22'), qty_hours: 1000 }
    let(:second_project) { Fabricate :project, status: :waiting, start_date: Time.zone.parse('2018-03-13'), end_date: Time.zone.parse('2018-03-21'), qty_hours: 400 }
    let(:third_project) { Fabricate :project, status: :maintenance, start_date: Time.zone.parse('2018-03-12'), end_date: Time.zone.parse('2018-03-13'), qty_hours: 800 }

    let!(:first_project_result) { Fabricate(:project_result, project: first_project, result_date: Time.zone.parse('2018-02-21'), known_scope: 110, throughput_upstream: 23, throughput_downstream: 2, qty_hours_upstream: 10, qty_hours_downstream: 20, flow_pressure: 4, qty_bugs_opened: 10, qty_bugs_closed: 2) }
    let!(:second_project_result) { Fabricate(:project_result, project: first_project, result_date: Time.zone.parse('2018-03-18'), known_scope: 220, throughput_upstream: 10, throughput_downstream: 22, qty_hours_upstream: 13, qty_hours_downstream: 25, flow_pressure: 1, qty_bugs_opened: 1, qty_bugs_closed: 5) }
    let!(:third_project_result) { Fabricate(:project_result, project: second_project, result_date: Time.zone.parse('2018-03-13'), known_scope: 221, throughput_upstream: 15, throughput_downstream: 21, qty_hours_upstream: 9, qty_hours_downstream: 32, flow_pressure: 7, qty_bugs_opened: 2, qty_bugs_closed: 7) }
    let!(:fourth_project_result) { Fabricate(:project_result, project: third_project, result_date: Time.zone.parse('2018-03-12'), known_scope: 219, throughput_upstream: 12, throughput_downstream: 24, qty_hours_upstream: 21, qty_hours_downstream: 11, flow_pressure: 1, qty_bugs_opened: 3, qty_bugs_closed: 6) }
    let!(:fifth_project_result) { Fabricate(:project_result, project: third_project, result_date: Time.zone.parse('2018-03-13'), known_scope: 125, throughput_upstream: 10, throughput_downstream: 62, qty_hours_upstream: 87, qty_hours_downstream: 16, flow_pressure: 10, qty_bugs_opened: 8, qty_bugs_closed: 9) }

    let!(:opened_demands) { Fabricate.times(20, :demand, project: first_project, project_result: first_project_result, created_date: Time.zone.parse('2018-02-21')) }
    let!(:first_demand) { Fabricate :demand, project: first_project, project_result: first_project_result, end_date: Time.zone.parse('2018-02-21'), leadtime: 2 * 86_400, effort_upstream: 10, effort_downstream: 5 }
    let!(:second_demand) { Fabricate :demand, project: first_project, project_result: first_project_result, end_date: Time.zone.parse('2018-02-22'), leadtime: 3 * 86_400, effort_upstream: 12, effort_downstream: 20 }
    let!(:third_demand) { Fabricate :demand, project: first_project, project_result: second_project_result, end_date: Time.zone.parse('2018-03-19'), leadtime: 1 * 86_400, effort_upstream: 27, effort_downstream: 40 }
    let!(:fourth_demand) { Fabricate :demand, project: first_project, project_result: second_project_result, end_date: Time.zone.parse('2018-03-18'), leadtime: 1 * 86_400, effort_upstream: 80, effort_downstream: 34 }
    let!(:fifth_demand) { Fabricate :demand, project: first_project, project_result: third_project_result, end_date: Time.zone.parse('2018-03-13'), leadtime: 4 * 86_400, effort_upstream: 56, effort_downstream: 25 }

    describe '.initialize' do
      context 'having projects' do
        subject(:report_data) { ReportData.new(Project.all) }

        it 'do the math and provides the correct information' do
          expect(report_data.all_projects).to eq Project.all
          expect(report_data.active_projects).to eq Project.active
          expect(report_data.all_projects_weeks).to eq [[8, 2018], [9, 2018], [10, 2018], [11, 2018], [12, 2018]]
          expect(report_data.active_weeks).to eq [[8, 2018], [9, 2018], [10, 2018], [11, 2018], [12, 2018]]
          expect(report_data.demands_burnup_data.ideal_per_week).to eq [113.2, 226.4, 339.6, 452.8, 566.0]
          expect(report_data.demands_burnup_data.current_per_week).to eq [25, 25, 25, 201, 201]
          expect(report_data.demands_burnup_data.scope_per_week).to eq [170, 170, 170, 566, 566]
          expect(report_data.hours_burnup_data.ideal_per_week).to eq [440.0, 880.0, 1320.0, 1760.0, 2200.0]
          expect(report_data.hours_burnup_data.current_per_week).to eq [30, 30, 30, 244, 244]
          expect(report_data.hours_burnup_data.scope_per_week).to eq [2200.0, 2200.0, 2200.0, 2200.0, 2200.0]
          expect(report_data.flow_pressure_data).to eq [4.0, 0.0, 0.0, 4.75, 0.0]
          expect(report_data.throughput_per_week).to eq([{ name: I18n.t('projects.charts.throughput_per_week.stage_stream.upstream'), data: [23, 0, 0, 47, 0] }, { name: I18n.t('projects.charts.throughput_per_week.stage_stream.downstream'), data: [2, 0, 0, 129, 0] }])
          expect(report_data.delivered_vs_remaining).to eq([{ name: I18n.t('projects.show.delivered_scope.text'), data: [201] }, { name: I18n.t('projects.show.scope_gap'), data: [365] }])
          expect(report_data.dates_and_odds.keys.count).to be >= 1
          expect(report_data.monte_carlo_data.dates_and_hits_hash.keys.count).to be >= 1
          expect(report_data.monte_carlo_data.monte_carlo_date_hash.keys.count).to be >= 1
          expect(report_data.effort_hours_per_month).to eq(keys: [[2018.0, 2.0], [2018.0, 3.0]], data: { upstream: [22.0, 163.0], downstream: [25.0, 99.0] })
          expect(report_data.lead_time_control_chart[:dispersion_source]).to eq [[first_demand.demand_id, (first_demand.leadtime / 86_400).to_f], [second_demand.demand_id, (second_demand.leadtime / 86_400).to_f], [fifth_demand.demand_id, (fifth_demand.leadtime / 86_400).to_f], [fourth_demand.demand_id, (fourth_demand.leadtime / 86_400).to_f], [third_demand.demand_id, (third_demand.leadtime / 86_400).to_f]]
          expect(report_data.lead_time_control_chart[:percentile_95_data]).to eq 3.8
          expect(report_data.lead_time_control_chart[:percentile_80_data]).to eq 3.2
          expect(report_data.lead_time_control_chart[:percentile_60_data]).to eq 2.4
          expect(report_data.leadtime_bins).to eq ['1.75 Dias', '3.25 Dias']
          expect(report_data.leadtime_histogram_data).to eq [3.0, 2.0]
          expect(report_data.throughput_bins).to eq ['0.5 demanda(s)', '1.5 demanda(s)']
          expect(report_data.throughput_histogram_data).to eq [2.0, 3.0]
          expect(report_data.weeekly_bugs_count_hash).to eq(dates_array: %w[2018-02-19 2018-02-26 2018-03-05 2018-03-12 2018-03-19], bugs_opened_count_array: [10, 0, 0, 14, 0], bugs_closed_count_array: [2, 0, 0, 27, 0])
          expect(report_data.weeekly_bugs_share_hash).to eq(dates_array: %w[2018-02-19 2018-02-26 2018-03-05 2018-03-12 2018-03-19], bugs_opened_share_array: [5.555555555555555, 5.555555555555555, 5.555555555555555, 4.067796610169491, 4.067796610169491])
        end
      end
      context 'having no projects' do
        subject(:report_data) { ReportData.new(Project.none) }

        it 'do the math and provides the correct information' do
          expect(report_data.all_projects).to eq []
          expect(report_data.active_projects).to eq []
          expect(report_data.all_projects_weeks).to eq []
          expect(report_data.active_weeks).to eq []
          expect(report_data.demands_burnup_data.ideal_per_week).to eq []
          expect(report_data.demands_burnup_data.current_per_week).to eq []
          expect(report_data.demands_burnup_data.scope_per_week).to eq []
          expect(report_data.hours_burnup_data.ideal_per_week).to eq []
          expect(report_data.hours_burnup_data.current_per_week).to eq []
          expect(report_data.hours_burnup_data.scope_per_week).to eq []
          expect(report_data.flow_pressure_data).to eq []
          expect(report_data.throughput_per_week).to eq([{ name: 'Upstream', data: [] }, { name: 'Downstream', data: [] }])
          expect(report_data.delivered_vs_remaining).to eq([{ name: 'Escopo Entregue', data: [0] }, { name: 'Restante do escopo', data: [0] }])
          expect(report_data.dates_and_odds.keys.count).to eq 0
          expect(report_data.monte_carlo_data.dates_and_hits_hash.keys.count).to eq 0
          expect(report_data.monte_carlo_data.monte_carlo_date_hash.keys.count).to eq 0
          expect(report_data.effort_hours_per_month).to eq(keys: [], data: { upstream: [], downstream: [] })
          expect(report_data.lead_time_control_chart[:dispersion_source]).to eq []
          expect(report_data.lead_time_control_chart[:percentile_95_data]).to eq 0
          expect(report_data.lead_time_control_chart[:percentile_80_data]).to eq 0
          expect(report_data.lead_time_control_chart[:percentile_60_data]).to eq 0
          expect(report_data.leadtime_bins).to eq []
          expect(report_data.leadtime_histogram_data).to eq []
          expect(report_data.throughput_bins).to eq []
          expect(report_data.throughput_histogram_data).to eq []
        end
      end
    end
    describe '#hours_per_demand_per_week' do
      subject(:report_data) { ReportData.new(Project.all) }
      it { expect(report_data.hours_per_demand_per_week).to eq [15.0, 0, 0, 1.6589147286821706, 0] }
    end
  end

  context 'having no projects' do
    describe '.initialize' do
      subject(:report_data) { ReportData.new(Project.all) }

      it 'returns empty arrays' do
        expect(report_data.all_projects).to eq []
        expect(report_data.active_projects).to eq []
        expect(report_data.active_weeks).to eq []
        expect(report_data.all_projects_weeks).to eq []
        expect(report_data.demands_burnup_data.ideal_per_week).to eq []
        expect(report_data.demands_burnup_data.current_per_week).to eq []
        expect(report_data.demands_burnup_data.scope_per_week).to eq []
        expect(report_data.flow_pressure_data).to eq []
        expect(report_data.throughput_per_week).to eq([{ name: I18n.t('projects.charts.throughput_per_week.stage_stream.upstream'), data: [] }, { name: I18n.t('projects.charts.throughput_per_week.stage_stream.downstream'), data: [] }])
        expect(report_data.delivered_vs_remaining).to eq([{ name: I18n.t('projects.show.delivered_scope.text'), data: [0] }, { name: I18n.t('projects.show.scope_gap'), data: [0] }])
      end
    end

    describe '#hours_per_demand_per_week' do
      subject(:report_data) { ReportData.new(Project.all) }
      it { expect(report_data.hours_per_demand_per_week).to eq [] }
    end
  end
end
