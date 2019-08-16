# frozen_string_literal: true

# == Schema Information
#
# Table name: team_members
#
#  billable                :boolean          default(TRUE)
#  billable_type           :integer          default("outsourcing")
#  company_id              :integer          not null, indexed => [name, jira_account_id]
#  created_at              :datetime         not null
#  end_date                :date
#  hours_per_month         :integer
#  id                      :bigint(8)        not null, primary key
#  jira_account_id         :string           indexed => [company_id, name]
#  jira_account_user_email :string
#  monthly_payment         :decimal(, )
#  name                    :string           not null, indexed => [company_id, jira_account_id]
#  start_date              :date
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_team_members_on_company_id_and_name_and_jira_account_id  (company_id,name,jira_account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_3ec60e399b  (company_id => companies.id)
#

class TeamMember < ApplicationRecord
  enum billable_type: { outsourcing: 0, consulting: 1, training: 2, domestic_product: 3 }

  belongs_to :company

  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships

  has_many :demand_comments, dependent: :nullify
  has_many :demand_blocks, inverse_of: :blocker, dependent: :destroy, foreign_key: :blocker_id
  has_many :demand_unblocks, class_name: 'DemandBlock', inverse_of: :unblocker, dependent: :destroy, foreign_key: :unblocker_id

  has_many :item_assignments, dependent: :destroy
  has_many :demands, through: :item_assignments

  validates :name, presence: true
  validates :name, uniqueness: { scope: %i[company_id jira_account_id], message: I18n.t('activerecord.attributes.team_member.validations.name_unique') }

  scope :active, -> { where('end_date IS NULL') }

  def to_hash
    { member_name: name, jira_account_id: jira_account_id }
  end

  def hours_per_day
    hours_per_month.to_f / 30.0
  end

  def active?
    end_date.blank?
  end
end
