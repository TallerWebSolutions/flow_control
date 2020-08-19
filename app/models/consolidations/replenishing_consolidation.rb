# frozen-string-literal: true

# == Schema Information
#
# Table name: replenishing_consolidations
#
#  id                               :bigint           not null, primary key
#  consolidation_date               :date             not null
#  customer_happiness               :decimal(, )
#  flow_pressure                    :decimal(, )
#  leadtime_80                      :decimal(, )
#  max_work_in_progress             :integer
#  montecarlo_80_percent            :decimal(, )
#  project_based_risks_to_deadline  :decimal(, )
#  project_throughput_data          :integer          is an Array
#  qty_selected_last_week           :decimal(, )
#  qty_using_pressure               :decimal(, )
#  relative_flow_pressure           :decimal(, )
#  team_based_montecarlo_80_percent :decimal(, )
#  team_based_odds_to_deadline      :decimal(, )
#  team_lead_time                   :decimal(, )
#  team_monte_carlo_weeks_max       :decimal(, )
#  team_monte_carlo_weeks_min       :decimal(, )
#  team_monte_carlo_weeks_std_dev   :decimal(, )
#  team_throughput_data             :integer          is an Array
#  team_wip                         :integer
#  work_in_progress                 :decimal(, )
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  project_id                       :integer          not null
#
# Indexes
#
#  idx_replenishing_unique                                  (project_id,consolidation_date) UNIQUE
#  index_replenishing_consolidations_on_consolidation_date  (consolidation_date)
#  index_replenishing_consolidations_on_project_id          (project_id)
#
# Foreign Keys
#
#  fk_rails_278fac0d87  (project_id => projects.id)
#

module Consolidations
  class ReplenishingConsolidation < ApplicationRecord
    belongs_to :project

    def average_team_throughput
      return 0 if team_throughput_data.blank?

      team_throughput_data.sum.to_f / team_throughput_data.count
    end

    def project_throughput_data_stddev
      Stats::StatisticsService.instance.standard_deviation(project_throughput_data)
    end

    def project_throughput_data_mode
      Stats::StatisticsService.instance.mode(project_throughput_data)
    end
  end
end
