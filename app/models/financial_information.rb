# frozen_string_literal: true

# == Schema Information
#
# Table name: financial_informations
#
#  id             :bigint           not null, primary key
#  expenses_total :decimal(, )      not null
#  finances_date  :date             not null
#  income_total   :decimal(, )      not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  company_id     :integer          not null
#
# Indexes
#
#  index_financial_informations_on_company_id  (company_id)
#
# Foreign Keys
#
#  fk_rails_573f757bcf  (company_id => companies.id)
#

class FinancialInformation < ApplicationRecord
  belongs_to :company

  validates :finances_date, :income_total, :expenses_total, presence: true

  scope :for_month, ->(date) { where('EXTRACT(MONTH FROM finances_date) = :month AND EXTRACT(YEAR FROM finances_date) = :year', month: date.month, year: date.year) }

  def to_h
    { id: id, finances_date: finances_date, income_total: income_total, expenses_total: expenses_total }.with_indifferent_access
  end

  def financial_result
    income_total.to_f - expenses_total.to_f
  end

  def cost_per_hour
    return 0 if project_delivered_hours.zero?

    expenses_total / project_delivered_hours
  end

  def income_per_hour
    return 0 if project_delivered_hours.zero?

    income_total / project_delivered_hours
  end

  def hours_per_demand
    return 0 if throughput_in_month.count.zero?

    project_delivered_hours.to_f / throughput_in_month.count
  end

  def project_delivered_hours
    company.consumed_hours_in_month(finances_date).to_f
  end

  def throughput_in_month
    company.throughput_in_month(finances_date)
  end

  def red?
    expenses_total > income_total
  end
end
