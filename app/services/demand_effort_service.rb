# frozen_string_literal: true

class DemandEffortService
  include Singleton

  # rubocop:disable Metrics/AbcSize
  def build_efforts_to_demand(demand)
    demand.demand_transitions.each do |transition|
      next unless transition.stage_compute_effort_to_project?

      end_date_for_assignment = [transition.last_time_out, Time.zone.now].compact.min

      assignments_in_dates = demand.item_assignments.for_dates(transition.last_time_in, end_date_for_assignment)
      top_effort_assignment = assignments_in_dates.max_by { |assign_in_date| assign_in_date.working_hours_until(transition.last_time_in, transition.last_time_out) }

      assignments_in_dates.each do |assignment|
        start_date = [assignment.start_time, transition.last_time_in].compact.max
        end_date = [assignment.finish_time, transition.last_time_out, Time.zone.now].compact.min

        demand_effort = DemandEffort.where(demand_transition: transition, item_assignment: assignment, demand: transition.demand).first_or_initialize

        next unless demand_effort.automatic_update?

        compute_and_save_effort(assignment, demand, demand_effort, end_date, start_date, top_effort_assignment, transition)
      end
    end

    return if demand.manual_effort?

    update_demand_effort_caches(demand)
  end
  # rubocop:enable Metrics/AbcSize

  private

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def compute_and_save_effort(assignment, demand, demand_effort, end_date, start_date, top_effort_assignment, transition)
    main_assignment = assignment == top_effort_assignment
    stage_percentage = transition.stage_percentage_to_project
    pairing_percentage = transition.stage_pairing_percentage_to_project
    pairing_percentage = 1 if main_assignment
    management_percentage = transition.stage_management_percentage_to_project

    total_blocked_in_assignment = demand.demand_blocks.kept.closed.active.for_date_interval(start_date, end_date).sum do |demand_block|
      start_date_to_block = [start_date, demand_block.block_time].compact.max
      end_date_to_block = [end_date, demand_block.unblock_time].compact.min

      TimeService.instance.compute_working_hours_for_dates(start_date_to_block, end_date_to_block) * pairing_percentage * (1 + management_percentage) * stage_percentage
    end

    effort_total = if (end_date - start_date) > 20.minutes
                     (TimeService.instance.compute_working_hours_for_dates(start_date, end_date) * pairing_percentage * (1 + management_percentage) * stage_percentage) - total_blocked_in_assignment
                   else
                     0
                   end

    demand_effort.update(effort_value: effort_total, total_blocked: total_blocked_in_assignment, stage_percentage: stage_percentage,
                         management_percentage: management_percentage, pairing_percentage: pairing_percentage, main_effort_in_transition: main_assignment,
                         start_time_to_computation: start_date, finish_time_to_computation: end_date)
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  def update_demand_effort_caches(demand)
    effort_upstream = demand.demand_efforts.upstream_efforts.sum(&:effort_value)
    effort_downstream = demand.demand_efforts.downstream_efforts.sum(&:effort_value)
    effort_development = demand.demand_efforts.developer_efforts.sum(&:effort_value)
    effort_design = demand.demand_efforts.designer_efforts.sum(&:effort_value)
    effort_management = demand.demand_efforts.manager_efforts.sum(&:effort_value)

    demand.update(effort_upstream: effort_upstream,
                  effort_downstream: effort_downstream,
                  effort_development: effort_development,
                  effort_design: effort_design,
                  effort_management: effort_management)
  end
end
