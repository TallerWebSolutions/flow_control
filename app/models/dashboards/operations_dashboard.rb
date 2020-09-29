# frozen_string_literal: true

# == Schema Information
#
# Table name: operations_dashboards
#
#  id                      :bigint           not null, primary key
#  bugs_count              :integer          default(0), not null
#  dashboard_date          :date             not null
#  delivered_demands_count :integer          default(0), not null
#  lead_time_max           :decimal(, )      default(0.0), not null
#  lead_time_min           :decimal(, )      default(0.0), not null
#  lead_time_p80           :decimal(, )      default(0.0), not null
#  projects_count          :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  first_delivery_id       :integer          not null
#  team_member_id          :integer          not null
#
# Indexes
#
#  index_operations_dashboards_on_team_member_id  (team_member_id)
#
# Foreign Keys
#
#  fk_rails_3c55d6de97  (team_member_id => team_members.id)
#  fk_rails_985b6d0e91  (first_delivery_id => demands.id)
#
module Dashboards
  class OperationsDashboard < ApplicationRecord
    belongs_to :team_member
    belongs_to :first_delivery, class_name: 'Demand'

    has_many :operations_dashboard_pairings, class_name: 'Dashboards::OperationsDashboardPairings', dependent: :destroy

    validates :team_member, :first_delivery, :dashboard_date, :bugs_count, :delivered_demands_count,
              :lead_time_max, :lead_time_min, :lead_time_p80, :projects_count, presence: true
  end
end
