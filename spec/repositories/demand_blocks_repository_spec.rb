# frozen_string_literal: true

RSpec.describe DemandBlocksRepository, type: :repository do
  describe '#closed_blocks_to_projects_and_period_grouped' do
    let!(:first_project) { Fabricate :project, status: :maintenance, start_date: 3.days.ago, end_date: 2.days.ago }
    let!(:second_project) { Fabricate :project, status: :executing, start_date: 3.days.ago, end_date: Time.zone.today }

    context 'having data' do
      let!(:first_demand) { Fabricate :demand, project: first_project }
      let!(:second_demand) { Fabricate :demand, project: first_project }
      let!(:third_demand) { Fabricate :demand, project: second_project }
      let!(:fourth_demand) { Fabricate :demand, project: first_project }

      let!(:fifth_demand) { Fabricate :demand, project: first_project }

      let!(:first_block) { Fabricate :demand_block, demand: first_demand, block_time: 1.hour.ago, unblock_time: Time.zone.today, active: true }
      let!(:second_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: 2.days.ago }
      let!(:third_block) { Fabricate :demand_block, demand: second_demand, block_time: 2.days.ago, unblock_time: 4.days.ago }
      let!(:fourth_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: Time.zone.yesterday }
      let!(:fifth_block) { Fabricate :demand_block, demand: third_demand, block_time: 5.days.ago, unblock_time: 3.days.ago }
      let!(:sixth_block) { Fabricate :demand_block, demand: fourth_demand, block_time: 2.days.ago, unblock_time: Time.zone.today }

      it 'returns the grouped data' do
        blocks_grouped_data = DemandBlocksRepository.instance.closed_blocks_to_projects_and_period_grouped([first_project, second_project], first_project.start_date, second_project.end_date)
        expect(blocks_grouped_data.keys).to eq([first_project.name])
        expect(blocks_grouped_data.values[0].first).to eq third_block
      end
    end

    context 'having no data' do
      it { expect(DemandBlocksRepository.instance.closed_blocks_to_projects_and_period_grouped([first_project, second_project], first_project.start_date, second_project.end_date)).to eq({}) }
    end
  end

  describe '#active_blocks_to_projects_and_period' do
    let!(:first_project) { Fabricate :project, status: :maintenance, start_date: 3.days.ago, end_date: 2.days.ago }
    let!(:second_project) { Fabricate :project, status: :executing, start_date: 3.days.ago, end_date: Time.zone.today }
    let!(:third_project) { Fabricate :project, status: :executing, start_date: 3.days.ago, end_date: Time.zone.today }

    context 'having data' do
      let!(:first_demand) { Fabricate :demand, project: first_project }
      let!(:second_demand) { Fabricate :demand, project: first_project }
      let!(:third_demand) { Fabricate :demand, project: second_project }
      let!(:fourth_demand) { Fabricate :demand, project: first_project }

      let!(:fifth_demand) { Fabricate :demand, project: third_project }

      let!(:first_block) { Fabricate :demand_block, demand: first_demand, block_time: 1.hour.ago, unblock_time: Time.zone.today, active: true }
      let!(:second_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: 2.days.ago, active: true }
      let!(:third_block) { Fabricate :demand_block, demand: second_demand, block_time: 2.days.ago, unblock_time: 4.days.ago, active: true }
      let!(:fourth_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: Time.zone.yesterday, active: true }
      let!(:fifth_block) { Fabricate :demand_block, demand: third_demand, block_time: 5.days.ago, unblock_time: 3.days.ago, active: true }
      let!(:sixth_block) { Fabricate :demand_block, demand: fourth_demand, block_time: 2.days.ago, unblock_time: Time.zone.today, active: true }

      let!(:seventh_block) { Fabricate :demand_block, demand: fifth_demand, block_time: 2.days.ago, unblock_time: Time.zone.today, active: true }

      it 'returns the grouped data' do
        blocks_grouped_data = DemandBlocksRepository.instance.active_blocks_to_projects_and_period([first_project, second_project], first_project.start_date, second_project.end_date)
        expect(blocks_grouped_data).to match_array [first_block, second_block, third_block, fourth_block, sixth_block]
      end
    end

    context 'having no data' do
      it { expect(DemandBlocksRepository.instance.active_blocks_to_projects_and_period([first_project, second_project], first_project.start_date, second_project.end_date)).to eq [] }
    end
  end

  describe '#accumulated_blocks_to_date' do
    let!(:first_project) { Fabricate :project, status: :maintenance, start_date: 3.days.ago, end_date: 2.days.ago }
    let!(:second_project) { Fabricate :project, status: :executing, start_date: 3.days.ago, end_date: Time.zone.today }

    context 'having data' do
      let!(:first_demand) { Fabricate :demand, project: first_project }
      let!(:second_demand) { Fabricate :demand, project: first_project }
      let!(:third_demand) { Fabricate :demand, project: second_project }
      let!(:fourth_demand) { Fabricate :demand, project: first_project }

      let!(:fifth_demand) { Fabricate :demand, project: first_project }

      let!(:first_block) { Fabricate :demand_block, demand: first_demand, block_time: 1.hour.ago, unblock_time: Time.zone.today, active: true }
      let!(:second_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: 2.days.ago }
      let!(:third_block) { Fabricate :demand_block, demand: second_demand, block_time: 2.days.ago, unblock_time: 4.days.ago }
      let!(:fourth_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: Time.zone.yesterday }
      let!(:fifth_block) { Fabricate :demand_block, demand: third_demand, block_time: 5.days.ago, unblock_time: 3.days.ago }
      let!(:sixth_block) { Fabricate :demand_block, demand: fourth_demand, block_time: 2.days.ago, unblock_time: Time.zone.today }

      it 'returns the grouped data' do
        blocks_grouped_data = DemandBlocksRepository.instance.accumulated_blocks_to_date([first_project, second_project], second_project.end_date)
        expect(blocks_grouped_data).to eq 4
      end
    end

    context 'having no data' do
      it { expect(DemandBlocksRepository.instance.accumulated_blocks_to_date([first_project, second_project], second_project.end_date)).to eq 0 }
    end
  end

  describe '#blocks_duration_per_stage' do
    before { travel_to Time.zone.local(2018, 3, 6, 10, 0, 0) }

    after { travel_back }

    let(:company) { Fabricate :company }

    let(:team) { Fabricate :team, company: company }

    let!(:first_project) { Fabricate :project, status: :maintenance, start_date: 3.days.ago, end_date: 2.days.ago, team: team }
    let!(:second_project) { Fabricate :project, status: :executing, start_date: 3.days.ago, end_date: Time.zone.today, team: team }

    let(:first_stage) { Fabricate :stage, company: company, teams: [team], order: 0, name: 'bbb', projects: [first_project, second_project] }
    let(:second_stage) { Fabricate :stage, company: company, teams: [team], order: 1, name: 'aaa', projects: [first_project, second_project] }

    context 'having data' do
      let!(:first_demand) { Fabricate :demand, project: first_project }
      let!(:second_demand) { Fabricate :demand, project: first_project }
      let!(:third_demand) { Fabricate :demand, project: second_project }
      let!(:fourth_demand) { Fabricate :demand, project: first_project }

      let!(:fifth_demand) { Fabricate :demand }

      let!(:first_transition) { Fabricate :demand_transition, stage: first_stage, demand: first_demand, last_time_in: 1.month.ago, last_time_out: Time.zone.today }
      let!(:second_transition) { Fabricate :demand_transition, stage: second_stage, demand: second_demand, last_time_in: 1.month.ago, last_time_out: Time.zone.today }

      let!(:first_block) { Fabricate :demand_block, demand: first_demand, block_time: 1.hour.ago, unblock_time: Time.zone.today, active: true }
      let!(:second_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: 30.hours.ago }
      let!(:third_block) { Fabricate :demand_block, demand: second_demand, block_time: 2.days.ago, unblock_time: 1.day.ago }
      let!(:fourth_block) { Fabricate :demand_block, demand: first_demand, block_time: 2.days.ago, unblock_time: Time.zone.yesterday }
      let!(:fifth_block) { Fabricate :demand_block, demand: third_demand, block_time: 5.days.ago, unblock_time: 3.days.ago }
      let!(:sixth_block) { Fabricate :demand_block, demand: fourth_demand, block_time: 2.days.ago, unblock_time: Time.zone.today }

      let!(:seventh_block) { Fabricate :demand_block, demand: fifth_demand, block_time: 4.days.ago, unblock_time: Time.zone.today }

      it 'returns the grouped data' do
        blocks_grouped_data = DemandBlocksRepository.instance.blocks_duration_per_stage(team.projects, 6.days.ago, Time.zone.now)
        expect(blocks_grouped_data[0][0]).to eq first_stage.name
        expect(blocks_grouped_data[0][1]).to eq 0
        expect(blocks_grouped_data[0][2] / 1.hour).to be_within(2.5).of(31.0)

        expect(blocks_grouped_data[1][0]).to eq second_stage.name
        expect(blocks_grouped_data[1][1]).to eq 1
        expect(blocks_grouped_data[1][2] / 1.hour).to be_within(2.5).of(24.0)
      end
    end

    context 'having no data' do
      it { expect(DemandBlocksRepository.instance.blocks_duration_per_stage(team.projects, 6.days.ago, Time.zone.now)).to eq [] }
    end
  end
end
