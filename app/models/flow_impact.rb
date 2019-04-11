# frozen_string_literal: true

# == Schema Information
#
# Table name: flow_impacts
#
#  created_at         :datetime         not null
#  demand_id          :integer          indexed
#  end_date           :datetime
#  id                 :bigint(8)        not null, primary key
#  impact_description :string           not null
#  impact_type        :integer          not null, indexed
#  project_id         :integer          not null, indexed
#  start_date         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_flow_impacts_on_demand_id    (demand_id)
#  index_flow_impacts_on_impact_type  (impact_type)
#  index_flow_impacts_on_project_id   (project_id)
#
# Foreign Keys
#
#  fk_rails_cda32ac094  (project_id => projects.id)
#  fk_rails_f6118b7a74  (demand_id => demands.id)
#

class FlowImpact < ApplicationRecord
  enum impact_type: { other_team_dependency: 0, api_not_ready: 1, customer_not_available: 2 }

  belongs_to :project
  belongs_to :demand

  validates :project, :start_date, :impact_type, :impact_description, presence: true
end