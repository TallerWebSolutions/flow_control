# frozen_string_literal: true

RSpec.describe Project, type: :model do
  context 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(waiting: 0, executing: 1, maintenance: 2, finished: 3, cancelled: 4, negotiating: 5) }
    it { is_expected.to define_enum_for(:project_type).with_values(outsourcing: 0, consulting: 1, training: 2, domestic_product: 3) }
  end

  context 'associations' do
    it { is_expected.to belong_to :company }
    it { is_expected.to belong_to :team }

    it { is_expected.to have_many(:project_risk_configs).dependent(:destroy) }
    it { is_expected.to have_many(:project_risk_alerts).dependent(:destroy) }
    it { is_expected.to have_many(:demands).dependent(:destroy) }
    it { is_expected.to have_many(:demand_blocks).through(:demands) }
    it { is_expected.to have_many(:stage_project_configs) }
    it { is_expected.to have_many(:stages).through(:stage_project_configs) }
    it { is_expected.to have_many(:integration_errors).dependent(:destroy) }
    it { is_expected.to have_many(:project_change_deadline_histories).dependent(:destroy) }
    it { is_expected.to have_many(:jira_project_configs).dependent(:destroy) }
    it { is_expected.to have_many(:flow_impacts).dependent(:destroy) }
    it { is_expected.to have_many(:project_consolidations).dependent(:destroy) }

    it { is_expected.to have_many(:user_project_roles).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:user_project_roles) }

    it { is_expected.to have_and_belong_to_many(:customers).dependent(:destroy) }
    it { is_expected.to have_and_belong_to_many(:products).dependent(:destroy) }
  end

  context 'validations' do
    context 'simple ones' do
      it { is_expected.to validate_presence_of :company }
      it { is_expected.to validate_presence_of :team }
      it { is_expected.to validate_presence_of :project_type }
      it { is_expected.to validate_presence_of :name }
      it { is_expected.to validate_presence_of :status }
      it { is_expected.to validate_presence_of :start_date }
      it { is_expected.to validate_presence_of :end_date }
      it { is_expected.to validate_presence_of :initial_scope }
      it { is_expected.to validate_presence_of :qty_hours }
      it { is_expected.to validate_presence_of :percentage_effort_to_bugs }
      it { is_expected.to validate_presence_of :max_work_in_progress }
    end

    context 'complex ones' do
      context 'values' do
        context 'with both value and hour value null' do
          let(:project) { Fabricate.build :project, value: nil, hour_value: nil }

          it 'fails the validation' do
            expect(project.valid?).to be false
            expect(project.errors.full_messages).to eq ['Valor do Projeto Valor ou Valor da hora é obrigatório', 'Valor da Hora Valor ou Valor da hora é obrigatório']
          end
        end

        context 'with both value and hour value null' do
          let(:project) { Fabricate.build :project, value: 10, hour_value: nil }

          it { expect(project.valid?).to be true }
        end

        context 'with both value and hour value null' do
          let(:project) { Fabricate.build :project, value: nil, hour_value: 10 }

          it { expect(project.valid?).to be true }
        end
      end

      context 'uniqueness' do
        context 'name to company' do
          let(:company) { Fabricate :company }

          context 'same name in same product' do
            let!(:project) { Fabricate :project, company: company, name: 'zzz' }
            let!(:other_project) { Fabricate.build :project, company: company, name: 'zzz' }

            it 'does not accept the model' do
              expect(other_project.valid?).to be false
              expect(other_project.errors[:name]).to eq ['Não deve repetir nome de projeto para a mesma empresa.']
            end
          end

          context 'different name in same company' do
            let!(:project) { Fabricate :project, company: company, name: 'zzz' }
            let!(:other_project) { Fabricate.build :project, company: company, name: 'aaa' }

            it { expect(other_project.valid?).to be true }
          end

          context 'same name in other company' do
            let!(:project) { Fabricate :project, company: company, name: 'zzz' }
            let!(:other_project) { Fabricate.build :project, name: 'zzz' }

            it { expect(other_project.valid?).to be true }
          end
        end
      end
    end
  end

  context 'scopes' do
    let!(:first_project) { Fabricate :project, status: :waiting, start_date: Time.zone.today }
    let!(:second_project) { Fabricate :project, status: :waiting, start_date: Time.zone.today }
    let!(:third_project) { Fabricate :project, status: :executing, end_date: Time.zone.today }
    let!(:fourth_project) { Fabricate :project, status: :maintenance, end_date: Time.zone.today }
    let!(:fifth_project) { Fabricate :project, status: :cancelled, end_date: Time.zone.today }
    let!(:sixth_project) { Fabricate :project, status: :finished, end_date: Time.zone.today }

    describe '.waiting_projects_starting_within_week' do
      it { expect(described_class.waiting_projects_starting_within_week).to match_array [first_project, second_project] }
    end

    describe '.running_projects_finishing_within_week' do
      it { expect(described_class.running_projects_finishing_within_week).to match_array [third_project, fourth_project] }
    end

    describe '.running' do
      it { expect(described_class.running).to match_array [third_project, fourth_project] }
    end

    describe '.active' do
      it { expect(described_class.active).to match_array [first_project, second_project, third_project, fourth_project] }
    end
  end

  describe '#total_days' do
    let(:project) { Fabricate :project, start_date: 1.day.ago, end_date: 1.day.from_now }

    it { expect(project.total_days).to be_within(0.1).of(3.9) }
  end

  describe '#remaining_days' do
    context 'when the end date is in the future' do
      let(:project) { Fabricate :project, start_date: 1.day.ago, end_date: 1.day.from_now }

      it { expect(project.remaining_days).to eq 2 }
    end

    context 'when the end date is in the past' do
      let(:project) { Fabricate :project, start_date: 2.days.ago, end_date: 1.day.ago }

      it { expect(project.remaining_days).to eq 0 }
    end

    context 'when the start date is in the future' do
      let(:project) { Fabricate :project, start_date: 2.days.from_now, end_date: 3.days.from_now }

      it { expect(project.remaining_days).to eq 2 }
    end

    context 'passing from_date as parameter' do
      let(:project) { Fabricate :project, start_date: 2.days.from_now, end_date: 10.days.from_now }

      it { expect(project.remaining_days(1.week.from_now)).to eq 4 }
    end
  end

  describe '#remaining_weeks' do
    context 'when the end date is in the future' do
      let(:project) { Fabricate :project, start_date: 1.week.ago, end_date: 1.week.from_now }

      it { expect(project.remaining_weeks).to eq 2 }
    end

    context 'when the end date is in the past' do
      let(:project) { Fabricate :project, start_date: 2.weeks.ago, end_date: 1.week.ago }

      it { expect(project.remaining_weeks).to eq 0 }
    end

    context 'when the start date is in the future' do
      let(:project) { Fabricate :project, start_date: 2.weeks.from_now, end_date: 3.weeks.from_now }

      it { expect(project.remaining_weeks).to eq 2 }
    end

    context 'passing from_date as parameter' do
      let(:project) { Fabricate :project, start_date: 2.weeks.from_now, end_date: 10.weeks.from_now }

      it { expect(project.remaining_weeks(1.week.from_now.to_date)).to eq 9 }
    end
  end

  describe '#percentage_remaining_days' do
    context 'total_days is higher than 0' do
      let(:project) { Fabricate :project, start_date: 1.day.ago, end_date: 1.day.from_now }

      it { expect(project.percentage_remaining_days).to eq 50 }
    end

    context 'the start and end days are in the same date' do
      let(:project) { Fabricate :project, start_date: Time.zone.today, end_date: Time.zone.today }

      it { expect(project.percentage_remaining_days).to eq 50 }
    end
  end

  describe '#consumed_hours' do
    let(:project) { Fabricate :project, end_date: 4.weeks.from_now }
    let!(:demand) { Fabricate :demand, project: project, effort_downstream: 200, effort_upstream: 10, end_date: 2.weeks.ago }
    let!(:other_demand) { Fabricate :demand, project: project, effort_downstream: 200, effort_upstream: 10, end_date: 2.weeks.ago }

    it { expect(project.consumed_hours.to_f).to eq 420 }
  end

  describe '#remaining_money' do
    context 'having hour_value' do
      let(:project) { Fabricate :project, qty_hours: 1000, value: 100_000, hour_value: 100 }
      let!(:demand) { Fabricate :demand, project: project, effort_downstream: 200, effort_upstream: 10, end_date: 2.weeks.ago }
      let!(:other_demand) { Fabricate :demand, project: project, effort_downstream: 200, effort_upstream: 10, end_date: 2.weeks.ago }

      it { expect(project.remaining_money.to_f).to eq 58_000.0 }
    end

    context 'having no hour_value' do
      let(:project) { Fabricate :project, start_date: 4.months.ago, qty_hours: 1000, value: 100_000, hour_value: nil }
      let!(:demand) { Fabricate :demand, project: project, effort_downstream: 200, effort_upstream: 10, end_date: 2.weeks.ago }
      let!(:other_demand) { Fabricate :demand, project: project, effort_downstream: 200, effort_upstream: 10, end_date: 2.weeks.ago }

      it { expect(project.remaining_money.to_f).to eq 58_000.0 }
    end
  end

  describe '#percentage_remaining_money' do
    context 'total_days is higher than 0' do
      let(:project) { Fabricate :project, start_date: 4.months.ago, qty_hours: 1000, value: 100_000, hour_value: 100 }

      it { expect(project.percentage_remaining_money).to eq((project.remaining_money / project.value) * 100) }
    end

    context 'value is 0' do
      let(:project) { Fabricate :project, value: 0 }

      it { expect(project.percentage_remaining_money).to eq 0 }
    end
  end

  describe '#flow_pressure' do
    context 'and the start and finish dates are in different days' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: Time.zone.parse('2018-03-05 22:00'), end_date: Time.zone.parse('2018-03-07 10:00') }

      context 'having demands' do
        let!(:opened_bugs) { Fabricate.times(20, :demand, project: project, demand_type: :bug, created_date: Time.zone.parse('2018-03-05 22:00')) }
        let!(:opened_features) { Fabricate.times(10, :demand, project: project, demand_type: :feature, created_date: Time.zone.parse('2018-03-06 22:00')) }
        let!(:delivered_bugs) { Fabricate.times(5, :demand, project: project, demand_type: :bug, created_date: Time.zone.parse('2018-03-05 22:00'), end_date: Time.zone.parse('2018-03-07 10:00')) }

        context 'specifying no date' do
          before { travel_to Time.zone.local(2018, 3, 6, 10, 0, 0) }

          after { travel_back }

          it { expect(project.flow_pressure).to be_within(0.5).of(25.1) }
        end

        context 'specifying a date' do
          it { expect(project.flow_pressure(Time.zone.parse('2018-03-05 22:00'))).to be_within(0.5).of(17.9) }
        end

        context 'having date negotiations' do
          let(:project) { Fabricate :project, initial_scope: 30, start_date: Time.zone.parse('2018-03-05 22:00'), end_date: Time.zone.parse('2018-03-12 10:00') }

          let!(:opened_bugs) { Fabricate.times(20, :demand, project: project, demand_type: :bug, created_date: Time.zone.parse('2018-03-05 22:00')) }
          let!(:opened_features) { Fabricate.times(10, :demand, project: project, demand_type: :feature, created_date: Time.zone.parse('2018-03-06 22:00')) }
          let!(:delivered_bugs) { Fabricate.times(5, :demand, project: project, demand_type: :bug, created_date: Time.zone.parse('2018-03-05 22:00'), end_date: Time.zone.parse('2018-03-07 10:00')) }

          let!(:first_project_change_deadline_history) { Fabricate :project_change_deadline_history, project: project, created_at: Time.zone.parse('2018-03-07 11:00'), previous_date: Time.zone.parse('2018-03-05 10:00'), new_date: Time.zone.parse('2018-03-06 23:00') }
          let!(:second_project_change_deadline_history) { Fabricate :project_change_deadline_history, project: project, created_at: Time.zone.parse('2018-03-08 07:00'), previous_date: Time.zone.parse('2018-03-09 10:00'), new_date: Time.zone.parse('2018-03-10 22:00') }
          let!(:third_project_change_deadline_history) { Fabricate :project_change_deadline_history, project: project, created_at: Time.zone.parse('2018-03-09 05:00'), previous_date: Time.zone.parse('2018-03-10 22:00'), new_date: Time.zone.parse('2018-03-12 22:00') }

          it { expect(project.flow_pressure(Time.zone.parse('2018-03-08 10:00'))).to be_within(0.2).of(16.7) }
        end
      end

      context 'having no demands' do
        before { travel_to Time.zone.local(2018, 3, 6, 10, 0, 0) }

        after { travel_back }

        it { expect(project.flow_pressure).to be_within(0.9).of(11.6) }
      end
    end

    context 'and the start and finish dates are in the same day' do
      before { travel_to Time.zone.local(2018, 3, 6, 10, 0, 0) }

      after { travel_back }

      let(:project) { Fabricate :project, initial_scope: 30, start_date: Time.zone.today, end_date: Time.zone.today }

      context 'having demands' do
        let!(:opened_features) { Fabricate.times(10, :demand, project: project, demand_type: :feature, end_date: nil) }

        it { expect(project.flow_pressure).to be_within(0.1).of(18.9) }
      end

      context 'having no demands' do
        it { expect(project.flow_pressure).to be_within(0.1).of(18.9) }
      end
    end
  end

  describe '#relative_flow_pressure' do
    context 'and the start and finish dates are in different days' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: Time.zone.parse('2018-03-05 22:00'), end_date: Time.zone.parse('2018-03-07 10:00') }

      context 'with demands' do
        let!(:opened_bugs) { Fabricate.times(20, :demand, project: project, demand_type: :bug, created_date: Time.zone.parse('2018-03-05 22:00')) }
        let!(:opened_features) { Fabricate.times(10, :demand, project: project, demand_type: :feature, created_date: Time.zone.parse('2018-03-06 22:00')) }
        let!(:delivered_bugs) { Fabricate.times(5, :demand, project: project, demand_type: :bug, created_date: Time.zone.parse('2018-03-05 22:00'), end_date: Time.zone.parse('2018-03-07 10:00')) }

        before { travel_to Time.zone.local(2018, 3, 6, 10, 0, 0) }

        after { travel_back }

        it { expect(project.relative_flow_pressure(80)).to be_within(0.5).of(31.4) }
      end

      context 'with no demands' do
        before { travel_to Time.zone.local(2018, 3, 6, 10, 0, 0) }

        after { travel_back }

        it { expect(project.relative_flow_pressure(10)).to be_within(0.9).of(116.1) }
      end

      context 'with no demands and no total pressure' do
        it { expect(project.relative_flow_pressure(nil)).to eq 0 }
      end

      context 'with no demands and 0 as total pressure' do
        it { expect(project.relative_flow_pressure(0)).to eq 0 }
      end
    end
  end

  describe '#risk_color' do
    let(:project) { Fabricate :project, end_date: 4.weeks.from_now }

    context 'having alerts' do
      let!(:risk_alert) { Fabricate :project_risk_alert, project: project, alert_color: :red, created_at: Time.zone.today }
      let!(:other_risk_alert) { Fabricate :project_risk_alert, project: project, alert_color: :green, created_at: 1.day.ago }

      it { expect(project.risk_color).to eq 'red' }
    end

    context 'having no alerts' do
      it { expect(project.risk_color).to eq 'green' }
    end
  end

  RSpec.shared_context 'demands with effort', shared_context: :metadata do
    let(:company) { Fabricate :company }
    let!(:customer) { Fabricate :customer, company: company }
    let!(:team) { Fabricate :team, company: company }
    let!(:team_member) { Fabricate :team_member, company: company, monthly_payment: 1300 }
    let!(:membership) { Fabricate :membership, team: team, team_member: team_member, hours_per_month: 100, start_date: 3.months.ago.to_date, end_date: nil }
    let!(:project) { Fabricate :project, team: team, customers: [customer], start_date: 2.months.ago, end_date: 3.months.from_now, qty_hours: 3000, value: 1_000_000, hour_value: 200, percentage_effort_to_bugs: 100 }

    let(:first_stage) { Fabricate :stage, company: company, stage_stream: :downstream, queue: false, end_point: false }
    let(:second_stage) { Fabricate :stage, company: company, stage_stream: :downstream, queue: false, end_point: true }
    let(:third_stage) { Fabricate :stage, company: company, stage_stream: :upstream, queue: false, end_point: true }

    let!(:first_stage_project_config) { Fabricate :stage_project_config, project: project, stage: first_stage, compute_effort: true, pairing_percentage: 80, stage_percentage: 100, management_percentage: 10 }
    let!(:second_stage_project_config) { Fabricate :stage_project_config, project: project, stage: second_stage, compute_effort: true, pairing_percentage: 80, stage_percentage: 100, management_percentage: 10 }
    let!(:third_stage_project_config) { Fabricate :stage_project_config, project: project, stage: third_stage, compute_effort: true, pairing_percentage: 80, stage_percentage: 100, management_percentage: 10 }

    let!(:first_demand) { Fabricate :demand, project: project, team: team, created_date: 2.weeks.ago, commitment_date: 8.days.ago, end_date: 1.week.ago, demand_type: :bug }
    let!(:second_demand) { Fabricate :demand, project: project, team: team, created_date: 2.weeks.ago, commitment_date: 9.days.ago, end_date: 1.week.ago }
    let!(:third_demand) { Fabricate :demand, project: project, team: team, created_date: 1.week.ago, commitment_date: 10.days.ago, end_date: 2.days.ago }
    let!(:fourth_demand) { Fabricate :demand, project: project, team: team, created_date: Time.zone.now, commitment_date: Time.zone.now, end_date: nil }

    let!(:first_item_assignment) { Fabricate :item_assignment, demand: first_demand, team_member: team_member, start_time: 1.month.ago, finish_time: nil }
    let!(:second_item_assignment) { Fabricate :item_assignment, demand: second_demand, team_member: team_member, start_time: 1.month.ago, finish_time: nil }
    let!(:third_item_assignment) { Fabricate :item_assignment, demand: third_demand, team_member: team_member, start_time: 7.weeks.ago, finish_time: nil }
    let!(:fourth_item_assignment) { Fabricate :item_assignment, demand: fourth_demand, team_member: team_member, start_time: 1.month.ago, finish_time: nil }

    let!(:first_transition) { Fabricate :demand_transition, stage: first_stage, demand: first_demand, last_time_in: 1.month.ago, last_time_out: 2.weeks.ago }
    let!(:second_transition) { Fabricate :demand_transition, stage: first_stage, demand: second_demand, last_time_in: 1.month.ago, last_time_out: 3.weeks.ago }

    let!(:third_transition) { Fabricate :demand_transition, stage: second_stage, demand: first_demand, last_time_in: Time.zone.today }
    let!(:fourth_transition) { Fabricate :demand_transition, stage: second_stage, demand: second_demand, last_time_in: Time.zone.today }

    let!(:fifth_transition) { Fabricate :demand_transition, stage: third_stage, demand: third_demand, last_time_in: 2.months.ago, last_time_out: 5.weeks.ago }
  end

  describe '#total_throughput' do
    context 'having results' do
      include_context 'demands with effort'
      it { expect(project.total_throughput).to eq 3 }
    end

    context 'having no results' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.day.ago, end_date: 1.week.from_now }

      it { expect(project.total_throughput).to eq 0 }
    end
  end

  describe '#avg_hours_per_demand' do
    before { travel_to Date.new(2018, 11, 19) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.avg_hours_per_demand).to eq 59.4 }
    end

    context 'having no data' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.day.ago, end_date: 1.week.from_now }

      it { expect(project.avg_hours_per_demand).to eq 0 }
    end
  end

  describe '#last_week_scope' do
    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.last_week_scope).to eq 33 }
    end

    context 'having no data' do
      let(:project) { Fabricate :project, initial_scope: 65, end_date: 4.weeks.from_now }

      it { expect(project.last_week_scope).to eq 65 }
    end
  end

  describe '#remaining_backlog' do
    context 'having demands' do
      context 'specifying no date' do
        include_context 'demands with effort'
        it { expect(project.remaining_backlog).to eq 30 }
      end

      context 'specifying a date' do
        include_context 'demands with effort'
        it { expect(project.remaining_backlog(2.weeks.ago)).to eq 32 }
      end
    end

    context 'having no demands' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.week.ago, end_date: 1.week.from_now }

      it { expect(project.remaining_backlog).to eq project.initial_scope }
    end
  end

  describe '#percentage_remaining_backlog' do
    context 'having demands' do
      context 'specifying no date' do
        include_context 'demands with effort'
        it { expect(project.percentage_remaining_backlog).to eq 0.8823529411764706 }
      end

      context 'specifying a date' do
        include_context 'demands with effort'
        it { expect(project.percentage_remaining_backlog(2.weeks.ago)).to eq 0.9411764705882353 }
      end
    end

    context 'having no demands' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.week.ago, end_date: 1.week.from_now }

      it { expect(project.percentage_remaining_backlog).to eq 1 }
    end
  end

  describe '#backlog_for' do
    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.backlog_for(1.week.ago)).to eq 33 }
      it { expect(project.backlog_for(2.weeks.ago)).to eq 32 }
      it { expect(project.backlog_for).to eq 34 }
    end

    context 'having no data' do
      let!(:project) { Fabricate :project, end_date: 4.weeks.from_now, initial_scope: 30 }

      it { expect(project.backlog_for(1.week.ago)).to eq 30 }
    end
  end

  describe '#total_hours_upstream' do
    before { travel_to Date.new(2018, 11, 19) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.total_hours_upstream).to eq 0.66e2 }
    end

    context 'having no data' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.day.ago, end_date: 1.week.from_now, qty_hours: 5000 }

      it { expect(project.total_hours_upstream).to eq 0 }
    end
  end

  describe '#total_hours_downstream' do
    before { travel_to Date.new(2018, 11, 19) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.total_hours_downstream.to_f).to eq 112.2 }
    end

    context 'having no data' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.day.ago, end_date: 1.week.from_now, qty_hours: 5000 }

      it { expect(project.total_hours_downstream).to eq 0 }
    end
  end

  describe '#total_hours_consumed' do
    before { travel_to Date.new(2018, 11, 19) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.total_hours_consumed.to_f).to eq 178.2 }
    end

    context 'having no data' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.day.ago, end_date: 1.week.from_now, qty_hours: 5000 }

      it { expect(project.total_hours_consumed).to eq 0 }
    end
  end

  describe '#remaining_hours' do
    before { travel_to Date.new(2018, 11, 19) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.remaining_hours.to_f).to eq 2821.8 }
    end

    context 'having no data' do
      let(:project) { Fabricate :project, initial_scope: 30, start_date: 1.day.ago, end_date: 1.week.from_now, qty_hours: 5000 }

      it { expect(project.remaining_hours).to eq 5000 }
    end
  end

  describe '#required_hours' do
    before { travel_to Time.zone.local(2018, 11, 19, 10, 0, 0) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.required_hours).to eq 1782.0 }
    end

    context 'having no data' do
      let!(:project) { Fabricate :project, end_date: 4.weeks.from_now, initial_scope: 30 }

      it { expect(project.required_hours).to eq 0 }
    end
  end

  describe '#required_hours_per_available_hours' do
    before { travel_to Date.new(2018, 11, 19) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.required_hours_per_available_hours).to be_within(0.02).of(0.63) }
    end

    context 'having no data' do
      let!(:project) { Fabricate :project, end_date: 4.weeks.from_now, initial_scope: 30 }

      it { expect(project.required_hours_per_available_hours).to eq 0 }
    end
  end

  describe '#backlog_unit_growth' do
    context 'having data for last week and 2 weeks ago' do
      include_context 'demands with effort'
      it { expect(project.backlog_unit_growth).to eq 1 }
    end

    context 'having no data to required weeks' do
      let!(:project) { Fabricate :project, end_date: 4.weeks.from_now, initial_scope: 30 }

      it { expect(project.backlog_unit_growth).to eq 0 }
    end
  end

  describe '#total_throughput_for' do
    before { travel_to Time.zone.local(2018, 11, 19, 10, 0, 0) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.total_throughput_for(Time.zone.today)).to eq 2 }
    end

    context 'having no result' do
      let!(:project) { Fabricate :project, end_date: 4.weeks.from_now, initial_scope: 30 }

      it { expect(project.total_throughput_for(1.week.ago)).to eq 0 }
    end
  end

  describe '#backlog_growth_rate' do
    before { travel_to Date.new(2018, 11, 19) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.backlog_growth_rate).to eq 0.030303030303030304 }
    end

    context 'having no data' do
      let!(:project) { Fabricate :project, start_date: 2.months.ago, end_date: 3.months.from_now }

      it { expect(project.backlog_growth_rate).to eq 0 }
    end
  end

  describe '#money_per_deadline' do
    before { travel_to Time.zone.local(2018, 11, 19, 10, 0, 0) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.money_per_deadline.to_f).to be_within(0.01).of(10_175.91) }
    end

    context 'having no data' do
      let!(:project) { Fabricate :project, start_date: 1.week.ago, initial_scope: 30, end_date: 3.weeks.from_now, value: 10_000, hour_value: 20 }

      it { expect(project.money_per_deadline.to_f).to be_within(8).of(454) }
    end
  end

  describe '#backlog_growth_throughput_rate' do
    before { travel_to Time.zone.local(2018, 11, 19, 10, 0, 0) }

    after { travel_back }

    context 'having data' do
      include_context 'demands with effort'
      it { expect(project.backlog_growth_throughput_rate).to eq 0.5 }
    end

    context 'having no data' do
      let!(:project) { Fabricate :project, end_date: 4.weeks.from_now, initial_scope: 30 }

      it { expect(project.backlog_growth_throughput_rate).to eq 0 }
    end
  end

  describe '#current_cost' do
    before { travel_to Time.zone.local(2018, 3, 6, 10, 0, 0) }

    after { travel_back }

    context 'having cost' do
      include_context 'demands with effort'
      it { expect(project.current_cost.to_f).to eq 33_000.0 }
    end

    context 'having no cost yet' do
      let(:project) { Fabricate :project, end_date: 4.weeks.from_now }

      it { expect(project.current_cost).to eq 0 }
    end
  end

  describe '#last_alert_for' do
    let(:project) { Fabricate :project, end_date: 4.weeks.from_now }
    let(:first_risk_config) { Fabricate :project_risk_config, risk_type: :no_money_to_deadline }
    let(:second_risk_config) { Fabricate :project_risk_config, risk_type: :flow_pressure }
    let(:third_risk_config) { Fabricate :project_risk_config, risk_type: :not_enough_available_hours }
    let!(:first_risk_alert) { Fabricate :project_risk_alert, project_risk_config: first_risk_config, project: project, created_at: 1.day.ago }
    let!(:second_risk_alert) { Fabricate :project_risk_alert, project_risk_config: first_risk_config, project: project, created_at: Time.zone.today }
    let!(:third_risk_alert) { Fabricate :project_risk_alert, project_risk_config: second_risk_config, project: project, created_at: Time.zone.today }

    context 'having alerts' do
      it { expect(project.last_alert_for(first_risk_config.risk_type)).to eq second_risk_alert }
    end

    context 'having no alerts to the type' do
      it { expect(project.last_alert_for(third_risk_config.risk_type)).to eq nil }
    end
  end

  describe '#red?' do
    let(:first_risk_config) { Fabricate :project_risk_config, project: project, risk_type: :no_money_to_deadline }
    let(:second_risk_config) { Fabricate :project_risk_config, project: project, risk_type: :backlog_growth_rate }

    context 'having a red alert as the last alert for the project' do
      let(:project) { Fabricate :project, start_date: 4.weeks.ago, end_date: 3.days.from_now }
      let!(:first_alert) { Fabricate :project_risk_alert, project_risk_config: first_risk_config, project: project, alert_color: :red, created_at: Time.zone.now }
      let!(:second_alert) { Fabricate :project_risk_alert, project_risk_config: second_risk_config, project: project, alert_color: :green, created_at: 1.hour.ago }

      it { expect(project.red?).to be true }
    end

    context 'having a green alert as the last alert for the project' do
      let(:project) { Fabricate :project, start_date: 4.weeks.ago, end_date: 3.days.from_now }
      let!(:first_alert) { Fabricate :project_risk_alert, project_risk_config: first_risk_config, project: project, alert_color: :green, created_at: Time.zone.now }
      let!(:second_alert) { Fabricate :project_risk_alert, project_risk_config: first_risk_config, project: project, alert_color: :red, created_at: 1.hour.ago }

      it { expect(project.red?).to be false }
    end

    context 'having a green alert as one type and a red as another type' do
      let(:project) { Fabricate :project, start_date: 4.weeks.ago, end_date: 3.days.from_now }
      let!(:first_alert) { Fabricate :project_risk_alert, project_risk_config: first_risk_config, project: project, alert_color: :green, created_at: Time.zone.now }
      let!(:second_alert) { Fabricate :project_risk_alert, project_risk_config: second_risk_config, project: project, alert_color: :red, created_at: 1.hour.ago }

      it { expect(project.red?).to be true }
    end

    context 'having no alerts' do
      let(:project) { Fabricate :project, start_date: 4.weeks.ago, end_date: 3.days.from_now }

      it { expect(project.red?).to be false }
    end
  end

  describe '#hours_per_month' do
    let(:project) { Fabricate :project, qty_hours: 100, start_date: Date.new(2018, 2, 20), end_date: Date.new(2018, 5, 23) }

    it { expect(project.hours_per_month).to be_within(0.2).of(31.9) }
  end

  describe '#money_per_month' do
    let(:project) { Fabricate :project, value: 100, start_date: Date.new(2018, 2, 20), end_date: Date.new(2018, 5, 23) }

    it { expect(project.money_per_month.to_f).to be_within(0.2).of(31.9) }
  end

  describe '#total_throughput_until' do
    let!(:project) { Fabricate :project, end_date: 4.weeks.from_now, initial_scope: 30 }

    context 'having data for last week' do
      let!(:opened_bugs) { Fabricate.times(20, :demand, project: project, demand_type: :bug, created_date: 1.week.ago) }
      let!(:opened_features) { Fabricate.times(10, :demand, project: project, demand_type: :feature, created_date: 3.weeks.ago) }
      let!(:delivered_bugs) { Fabricate.times(5, :demand, project: project, demand_type: :bug, created_date: 2.weeks.ago, end_date: 1.week.ago) }
      let!(:delivered_features) { Fabricate.times(14, :demand, project: project, demand_type: :feature, created_date: 2.weeks.ago, end_date: 2.weeks.ago) }

      it { expect(project.total_throughput_until(2.weeks.ago)).to eq 14 }
    end

    context 'having no data' do
      it { expect(project.total_throughput_until(1.week.ago)).to eq 0 }
    end
  end

  describe '#percentage_of_demand_type' do
    let(:project) { Fabricate :project }

    context 'the chore type' do
      context 'when there is no chores' do
        let!(:bug_demand) { Fabricate :demand, demand_type: :bug, project: project }
        let!(:feature_demand) { Fabricate :demand, demand_type: :feature, project: project }

        it { expect(project.percentage_of_demand_type(:chore)).to eq 0 }
      end

      context 'when there is no demands' do
        it { expect(project.percentage_of_demand_type(:chore)).to eq 0 }
      end

      context 'when there is chores' do
        let!(:feature_demand) { Fabricate :demand, demand_type: :feature, project: project }
        let!(:other_feature_demand) { Fabricate :demand, demand_type: :feature, project: project }
        let!(:chore_demand) { Fabricate :demand, demand_type: :chore, project: project }
        let!(:bug_demand) { Fabricate :demand, demand_type: :bug, project: project }

        it { expect(project.percentage_of_demand_type(:chore)).to eq 25 }
      end
    end

    context 'the feature type' do
      context 'when there is no features' do
        let!(:bug_demand) { Fabricate :demand, demand_type: :bug, project: project }
        let!(:chore_demand) { Fabricate :demand, demand_type: :chore, project: project }

        it { expect(project.percentage_of_demand_type(:feature)).to eq 0 }
      end

      context 'when there is no demands' do
        it { expect(project.percentage_of_demand_type(:feature)).to eq 0 }
      end

      context 'when there is features' do
        let!(:feature_demand) { Fabricate :demand, demand_type: :feature, project: project }
        let!(:other_feature_demand) { Fabricate :demand, demand_type: :feature, project: project }
        let!(:chore_demand) { Fabricate :demand, demand_type: :chore, project: project }
        let!(:bug_demand) { Fabricate :demand, demand_type: :bug, project: project }

        it { expect(project.percentage_of_demand_type(:feature)).to eq 50 }
      end
    end

    context 'the bug type' do
      context 'when there is no bugs' do
        let!(:feature_demand) { Fabricate :demand, demand_type: :feature, project: project }
        let!(:chore_demand) { Fabricate :demand, demand_type: :chore, project: project }

        it { expect(project.percentage_of_demand_type(:bug)).to eq 0 }
      end

      context 'when there is no demands' do
        it { expect(project.percentage_of_demand_type(:bug)).to eq 0 }
      end

      context 'when there is bugs' do
        let!(:feature_demand) { Fabricate :demand, demand_type: :feature, project: project }
        let!(:other_feature_demand) { Fabricate :demand, demand_type: :feature, project: project }
        let!(:chore_demand) { Fabricate :demand, demand_type: :chore, project: project }
        let!(:bug_demand) { Fabricate :demand, demand_type: :bug, project: project }

        it { expect(project.percentage_of_demand_type(:bug)).to eq 25 }
      end
    end
  end

  describe '#average_block_duration' do
    before { travel_to Time.zone.local(2018, 5, 21, 10, 0, 0) }

    after { travel_back }

    let(:project) { Fabricate :project }

    context 'having blocks' do
      let(:demand) { Fabricate :demand, demand_type: :bug, project: project }
      let!(:discarded_demand_block) { Fabricate :demand_block, demand: demand, unblock_time: 1.day.from_now, discarded_at: 1.day.ago }
      let!(:demand_block) { Fabricate :demand_block, demand: demand, block_time: 1.day.ago, unblock_time: 1.day.from_now }
      let!(:other_demand_block) { Fabricate :demand_block, demand: demand, block_time: 1.day.ago, unblock_time: 2.days.from_now }

      it { expect(project.average_block_duration.to_f).to eq 15 }
    end

    context 'having no demands' do
      it { expect(project.average_block_duration).to eq 0 }
    end

    context 'having no valid blocks' do
      let(:demand) { Fabricate :demand, demand_type: :bug, project: project }
      let!(:discarded_demand_block) { Fabricate :demand_block, demand: demand, discarded_at: 1.day.ago, block_duration: 100 }

      it { expect(project.average_block_duration).to eq 0 }
    end
  end

  describe '#leadtime_for_class_of_service' do
    before { travel_to Time.zone.local(2018, 5, 21, 10, 0, 0) }

    after { travel_back }

    let(:project) { Fabricate :project }

    context 'having demands' do
      let!(:expedite_demand) { Fabricate :demand, class_of_service: :expedite, commitment_date: 2.days.ago, project: project, end_date: Time.zone.today }
      let!(:other_expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project, commitment_date: 1.day.ago, end_date: Time.zone.today }
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project, end_date: Time.zone.today, leadtime: 80 }

      it { expect(project.leadtime_for_class_of_service(:expedite).to_f).to eq 119_520.0 }
      it { expect(project.leadtime_for_class_of_service(:expedite, 60).to_f).to eq 102_240.0 }
    end

    context 'having no demands' do
      let!(:expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project, end_date: Time.zone.today, leadtime: 100 }
      let!(:other_expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project, end_date: Time.zone.today, leadtime: 80 }

      it { expect(project.leadtime_for_class_of_service(:standard)).to eq 0 }
    end
  end

  describe '#general_leadtime' do
    before { travel_to Time.zone.local(2018, 5, 21, 10, 0, 0) }

    after { travel_back }

    let(:project) { Fabricate :project }

    context 'having demands' do
      let!(:expedite_demand) { Fabricate :demand, demand_type: :bug, project: project, commitment_date: 2.days.ago, end_date: Time.zone.today }
      let!(:other_expedite_demand) { Fabricate :demand, demand_type: :bug, project: project, commitment_date: 1.day.ago, end_date: Time.zone.today }
      let!(:standard_demand) { Fabricate :demand, demand_type: :feature, project: project, end_date: Time.zone.today }

      it { expect(project.general_leadtime.to_f).to eq 102_240.00000000001 }
    end

    context 'having no demands' do
      it { expect(project.general_leadtime).to eq 0 }
    end
  end

  describe '#active_kept_closed_blocks' do
    let(:project) { Fabricate :project }
    let(:demand) { Fabricate :demand, project: project }
    let(:other_demand) { Fabricate :demand, project: project }

    context 'having blocks' do
      let!(:inactive_demand_block) { Fabricate :demand_block, demand: demand, active: false, unblock_time: 1.day.from_now, discarded_at: nil }
      let!(:discarded_demand_block) { Fabricate :demand_block, demand: demand, active: true, unblock_time: 2.days.from_now, discarded_at: Time.zone.yesterday }
      let!(:inactive_and_discarded_demand_block) { Fabricate :demand_block, demand: demand, active: false, unblock_time: 1.day.from_now, discarded_at: Time.zone.yesterday }
      let!(:active_demand_block) { Fabricate :demand_block, demand: demand, active: true, unblock_time: 1.day.from_now, discarded_at: nil }
      let!(:other_active_demand_block) { Fabricate :demand_block, demand: demand, active: true, unblock_time: 1.day.from_now, discarded_at: nil }
      let!(:opened_active_demand_block) { Fabricate :demand_block, demand: demand, active: true, unblock_time: nil, discarded_at: nil }

      it { expect(project.active_kept_closed_blocks).to eq [active_demand_block, other_active_demand_block] }
    end

    context 'having no active and not discarded blocks' do
      let!(:inactive_demand_block) { Fabricate :demand_block, demand: demand, active: false, discarded_at: nil }
      let!(:discarded_demand_block) { Fabricate :demand_block, demand: demand, active: true, discarded_at: Time.zone.yesterday }
      let!(:inactive_and_discarded_demand_block) { Fabricate :demand_block, demand: demand, active: false, discarded_at: Time.zone.yesterday }

      it { expect(project.active_kept_closed_blocks).to eq [] }
    end

    context 'having no blocks' do
      it { expect(project.active_kept_closed_blocks).to eq [] }
    end
  end

  describe '#percentage_expedite' do
    let(:project) { Fabricate :project }

    context 'when there is no expedites' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }

      it { expect(project.percentage_expedite).to eq 0 }
    end

    context 'when there is no demands' do
      it { expect(project.percentage_expedite).to eq 0 }
    end

    context 'when there is expedites' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project }
      let!(:expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project }

      it { expect(project.percentage_expedite).to eq 25 }
    end
  end

  describe '#demands_of_class_of_service' do
    let(:project) { Fabricate :project }

    context 'when there is no expedites' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }

      it { expect(project.demands_of_class_of_service(:expedite)).to eq [] }
    end

    context 'when there is no demands' do
      it { expect(project.demands_of_class_of_service).to eq [] }
    end

    context 'when there is expedites' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project }
      let!(:expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project }

      it { expect(project.demands_of_class_of_service(:expedite)).to eq [expedite_demand] }
    end
  end

  describe '#percentage_standard' do
    let(:project) { Fabricate :project }

    context 'when there is no standards' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }

      it { expect(project.percentage_standard).to eq 0 }
    end

    context 'when there is no demands' do
      it { expect(project.percentage_standard).to eq 0 }
    end

    context 'when there is standard' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project }
      let!(:expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project }

      it { expect(project.percentage_standard).to eq 25 }
    end
  end

  describe '#percentage_intangible' do
    let(:project) { Fabricate :project }

    context 'when there is no intangibles' do
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }

      it { expect(project.percentage_intangible).to eq 0 }
    end

    context 'when there is no demands' do
      it { expect(project.percentage_intangible).to eq 0 }
    end

    context 'when there is intangible' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project }
      let!(:expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project }

      it { expect(project.percentage_intangible).to eq 25 }
    end
  end

  describe '#percentage_fixed_date' do
    let(:project) { Fabricate :project }

    context 'when there is no fixed_dates' do
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project }
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }

      it { expect(project.percentage_fixed_date).to eq 0 }
    end

    context 'when there is no demands' do
      it { expect(project.percentage_fixed_date).to eq 0 }
    end

    context 'when there is fixed dates' do
      let!(:intangible_demand) { Fabricate :demand, class_of_service: :intangible, project: project }
      let!(:fixed_date_demand) { Fabricate :demand, class_of_service: :fixed_date, project: project }
      let!(:standard_demand) { Fabricate :demand, class_of_service: :standard, project: project }
      let!(:expedite_demand) { Fabricate :demand, class_of_service: :expedite, project: project }

      it { expect(project.percentage_fixed_date).to eq 25 }
    end
  end

  describe '#add_user' do
    context 'when already has the user' do
      let(:user) { Fabricate :user }
      let!(:project) { Fabricate :project }

      before { project.add_user(user) }

      it { expect(project.users).to eq [user] }
    end

    context 'when does not have the user' do
      let(:user) { Fabricate :user }
      let!(:project) { Fabricate :project }

      before { project.add_user(user) }

      it { expect(project.users).to eq [user] }
    end
  end

  describe '#add_customer' do
    let(:customer) { Fabricate :customer }

    context 'when the project does not have the customer yet' do
      let(:project) { Fabricate :project }

      before { project.add_customer(customer) }

      it { expect(project.reload.customers).to eq [customer] }
    end

    context 'when the project has the customer' do
      let(:project) { Fabricate :project, customers: [customer] }

      before { project.add_customer(customer) }

      it { expect(project.reload.customers).to eq [customer] }
    end
  end

  describe '#remove_customer' do
    let(:customer) { Fabricate :customer }

    context 'when the project does not have the customer yet' do
      let(:project) { Fabricate :project }

      before { project.remove_customer(customer) }

      it { expect(project.reload.customers).to eq [] }
    end

    context 'when the project has the customer' do
      let(:project) { Fabricate :project, customers: [customer] }

      before { project.remove_customer(customer) }

      it { expect(project.reload.customers).to eq [] }
    end
  end

  describe '#add_product' do
    let(:product) { Fabricate :product }

    context 'when the project does not have the product yet' do
      let(:project) { Fabricate :project }

      before { project.add_product(product) }

      it { expect(project.reload.products).to eq [product] }
    end

    context 'when the project has the product' do
      let(:project) { Fabricate :project, products: [product] }

      before { project.add_product(product) }

      it { expect(project.reload.products).to eq [product] }
    end
  end

  describe '#remove_product' do
    let(:product) { Fabricate :product }

    context 'when the project does not have the product yet' do
      let(:project) { Fabricate :project }

      before { project.remove_product(product) }

      it { expect(project.reload.products).to eq [] }
    end

    context 'when the project has the product' do
      let(:project) { Fabricate :project, products: [product] }

      before { project.remove_product(product) }

      it { expect(project.reload.products).to eq [] }
    end
  end

  describe '#aging' do
    context 'when already has the user' do
      let(:user) { Fabricate :user }
      let!(:project) { Fabricate :project, start_date: 4.days.ago.to_date, end_date: Time.zone.today }

      it { expect(project.aging).to eq 4 }
    end
  end

  describe '#aging_today' do
    let!(:project) { Fabricate :project, start_date: 4.days.ago.to_date, end_date: 1.day.from_now.to_date }

    it { expect(project.aging_today).to eq 4 }
  end

  describe '#odds_to_deadline' do
    context 'with project consolidations' do
      let(:project) { Fabricate :project, end_date: 4.weeks.from_now }
      let!(:project_consolidation) { Fabricate :project_consolidation, project: project, consolidation_date: 1.day.ago, project_monte_carlo_weeks: [0, 0, 0, 2, 3, 4, 5, 6, 6, 6, 7] }
      let!(:other_project_consolidation) { Fabricate :project_consolidation, project: project, consolidation_date: 2.days.ago }

      it { expect(project.odds_to_deadline).to eq 0.6363636363636364 }
    end

    context 'without project consolidations' do
      let(:project) { Fabricate :project }

      it { expect(project.odds_to_deadline).to eq 0 }
    end
  end

  describe '#current_risk_to_deadline' do
    context 'with project consolidations' do
      let(:project) { Fabricate :project, end_date: 2.weeks.from_now }
      let!(:project_consolidation) { Fabricate :project_consolidation, project: project, consolidation_date: 1.day.ago, project_monte_carlo_weeks: [0, 0, 0, 2, 3, 4, 5, 6, 6, 6, 7] }
      let!(:other_project_consolidation) { Fabricate :project_consolidation, project: project, consolidation_date: 2.days.ago }

      it { expect(project.current_risk_to_deadline).to eq 0.5454545454545454 }
    end

    context 'without project consolidations' do
      let(:project) { Fabricate :project }

      it { expect(project.current_risk_to_deadline).to eq 1 }
    end
  end

  describe '#consolidations_last_update' do
    context 'with project consolidations' do
      let(:project) { Fabricate :project }
      let(:consolidation_date_one_day) { 1.day.ago }
      let(:consolidation_date_two_days) { 2.days.ago }

      let!(:project_consolidation) { Fabricate :project_consolidation, project: project, consolidation_date: consolidation_date_one_day, updated_at: consolidation_date_one_day }
      let!(:other_project_consolidation) { Fabricate :project_consolidation, project: project, consolidation_date: consolidation_date_two_days, updated_at: consolidation_date_two_days }

      it { expect(project.consolidations_last_update.to_date).to eq consolidation_date_one_day.to_date }
    end

    context 'without project consolidations' do
      let(:project) { Fabricate :project }

      it { expect(project.consolidations_last_update).to be_nil }
    end
  end

  describe '#failure_load' do
    let(:project) { Fabricate :project, end_date: 4.weeks.from_now, qty_hours: 2000 }
    let(:other_project) { Fabricate :project, end_date: 4.weeks.from_now }

    context 'with data' do
      let!(:first_demand) { Fabricate :demand, project: project, demand_type: :feature, created_date: 2.weeks.ago, end_date: 1.week.ago, effort_downstream: 20, effort_upstream: 30 }
      let!(:second_demand) { Fabricate :demand, project: project, demand_type: :bug, created_date: 2.weeks.ago, end_date: 1.week.ago, effort_downstream: 40, effort_upstream: 35 }
      let!(:third_demand) { Fabricate :demand, project: project, demand_type: :bug, created_date: 1.week.ago, end_date: 2.days.ago, effort_downstream: 10, effort_upstream: 78 }

      it { expect(project.failure_load).to eq 66.66666666666666 }
    end

    context 'with no data' do
      it { expect(project.failure_load).to eq 0 }
    end
  end

  describe '#first_deadline' do
    let(:project) { Fabricate :project, end_date: 4.weeks.from_now, qty_hours: 2000 }

    context 'with data' do
      let!(:project_change_deadline_history) { Fabricate :project_change_deadline_history, project: project, previous_date: 3.days.ago }
      let!(:other_project_change_deadline_history) { Fabricate :project_change_deadline_history, project: project, previous_date: 5.days.ago }

      it { expect(project.first_deadline).to eq other_project_change_deadline_history.previous_date }
    end

    context 'with no data' do
      it { expect(project.first_deadline).to eq project.end_date }
    end
  end

  describe '#days_difference_between_first_and_last_deadlines' do
    let(:project) { Fabricate :project, end_date: 4.weeks.from_now, qty_hours: 2000 }

    context 'with data' do
      let!(:project_change_deadline_history) { Fabricate :project_change_deadline_history, project: project, previous_date: 3.days.ago }
      let!(:other_project_change_deadline_history) { Fabricate :project_change_deadline_history, project: project, previous_date: 5.days.ago }

      it { expect(project.days_difference_between_first_and_last_deadlines).to eq 33 }
    end

    context 'with no data' do
      it { expect(project.days_difference_between_first_and_last_deadlines).to eq 0 }
    end
  end

  describe '#total_weeks' do
    let(:project) { Fabricate :project, start_date: Time.zone.today, end_date: 4.weeks.from_now, qty_hours: 2000 }

    it { expect(project.total_weeks).to eq 5.1428571428571415 }
  end

  describe '#past_weeks' do
    context 'with running project' do
      let(:project) { Fabricate :project, status: :executing, start_date: Time.zone.today, end_date: 4.weeks.from_now, qty_hours: 2000 }

      it { expect(project.past_weeks).to eq 1.1428571428571412 }
    end

    context 'with finished project' do
      let(:project) { Fabricate :project, status: :finished, start_date: Time.zone.today, end_date: 4.weeks.from_now, qty_hours: 2000 }

      it { expect(project.past_weeks).to eq 5.1428571428571415 }
    end
  end

  describe '#average_speed_per_week' do
    context 'with demands' do
      let(:project) { Fabricate :project, status: :executing, start_date: Time.zone.today, end_date: 4.weeks.from_now, qty_hours: 2000 }
      let!(:demands) { Fabricate.times(40, :demand, project: project, end_date: 2.days.from_now) }

      it { expect(project.average_speed_per_week).to eq 35.00000000000005 }
    end

    context 'with no demands' do
      let(:project) { Fabricate :project, status: :finished, start_date: Time.zone.today, end_date: 4.weeks.from_now, qty_hours: 2000 }

      it { expect(project.average_speed_per_week).to eq 0 }
    end
  end

  describe '#average_demand_aging' do
    context 'with demands' do
      let(:project) { Fabricate :project, status: :executing, start_date: Time.zone.today, end_date: 4.weeks.from_now, qty_hours: 2000 }
      let!(:demands) { Fabricate.times(10, :demand, project: project, created_date: 1.day.ago, end_date: 2.days.from_now) }
      let!(:older_demands) { Fabricate.times(10, :demand, project: project, created_date: 3.days.ago, end_date: 2.days.from_now) }

      it { expect(project.average_demand_aging.round(2)).to eq 4.00 }
    end

    context 'with no demands' do
      let(:project) { Fabricate :project, status: :finished, start_date: Time.zone.today, end_date: 4.weeks.from_now, qty_hours: 2000 }

      it { expect(project.average_demand_aging).to eq 0 }
    end
  end
end
