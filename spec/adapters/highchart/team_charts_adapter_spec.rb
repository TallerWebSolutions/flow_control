# frozen_string_literal: true

RSpec.describe Highchart::TeamChartsAdapter, type: :service do
  before { travel_to Time.zone.local(2018, 2, 20, 10, 0, 0) }

  after { travel_back }

  describe '#average_demand_cost' do
    let(:company) { Fabricate :company }
    let(:customer) { Fabricate :customer, company: company }

    let(:team) { Fabricate :team, company: company }
    let!(:team_member) { Fabricate :team_member, team: team, hours_per_month: 20, start_date: 3.months.ago, end_date: nil, monthly_payment: 10_000 }
    let!(:other_team_member) { Fabricate :team_member, team: team, hours_per_month: 160, start_date: 4.months.ago, end_date: 3.months.ago }

    context 'having projects' do
      let!(:first_project) { Fabricate :project, company: company, team: team, customers: [customer], status: :maintenance, start_date: 3.months.ago, end_date: 2.months.ago }
      let!(:second_project) { Fabricate :project, company: company, team: team, customers: [customer], status: :executing, start_date: 40.days.ago, end_date: 1.month.ago }

      let!(:first_demand) { Fabricate :demand, project: first_project, effort_downstream: 200, effort_upstream: 10, created_date: 74.days.ago, end_date: 35.days.ago }
      let!(:second_demand) { Fabricate :demand, project: first_project, effort_downstream: 400, effort_upstream: 130, created_date: 65.days.ago, end_date: 1.month.ago }
      let!(:third_demand) { Fabricate :demand, project: second_project, effort_downstream: 100, effort_upstream: 20, end_date: nil }

      context 'monthly basis x axis' do
        it 'builds the data structure for average_demand_cost monthly' do
          team_chart_data = described_class.new(team, first_project.start_date, second_project.end_date, 'month')

          expect(team_chart_data.average_demand_cost).to eq(data: [10_000.0, 10_000.0, 5000.0], x_axis: TimeService.instance.months_between_of(first_project.start_date, second_project.end_date))
        end
      end

      context 'weekly basis x axis' do
        it 'builds the data structure for average_demand_cost weekly' do
          team_chart_data = described_class.new(team, first_project.start_date, second_project.end_date, 'week')

          expect(team_chart_data.average_demand_cost).to eq(data: [2500.0, 2500.0, 2500.0, 2500.0, 2500.0, 2500.0, 2500.0, 2500.0, 1250.0], x_axis: TimeService.instance.weeks_between_of(first_project.start_date, second_project.end_date))
        end
      end

      context 'dayly basis x axis' do
        it 'builds the data structure for average_demand_cost dayly' do
          team_chart_data = described_class.new(team, second_project.start_date, second_project.end_date, 'day')

          expect(team_chart_data.average_demand_cost).to eq(data: [333.3333333333333, 333.3333333333333, 333.3333333333333, 333.3333333333333, 333.3333333333333, 333.3333333333333, 333.3333333333333, 333.3333333333333, 333.3333333333333, 333.3333333333333], x_axis: TimeService.instance.days_between_of(second_project.start_date, second_project.end_date))
        end
      end
    end
  end
end
