# frozen_string_literal: true

# == Schema Information
#
# Table name: financial_informations
#
#  company_id     :integer          not null, indexed
#  created_at     :datetime         not null
#  expenses_total :decimal(, )      not null
#  finances_date  :date             not null
#  id             :bigint(8)        not null, primary key
#  income_total   :decimal(, )      not null
#  updated_at     :datetime         not null
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

  scope :for_month, ->(month, year) { where('EXTRACT(MONTH FROM finances_date) = :month AND EXTRACT(YEAR FROM finances_date) = :year', month: month, year: year) }

  def financial_result
    income_total.to_f - expenses_total.to_f
  end

  def cost_per_hour
    expenses_total / hours_delivered_operation_result
  end

  def hours_per_demand
    hours_delivered_operation_result.to_f / throughput_operation_result.to_f
  end

  def project_delivered_hours
    ProjectResultsRepository.instance.project_results_for_company_month(company, finances_date).sum(&:project_delivered_hours)
  end

  def hours_delivered_operation_result
    OperationResultsRepository.instance.operation_results_for_company_month(company, finances_date.month, finances_date.year).sum(&:delivered_hours)
  end

  def throughput_operation_result
    OperationResultsRepository.instance.operation_results_for_company_month(company, finances_date.month, finances_date.year).sum(&:total_th)
  end

  def red?
    expenses_total > income_total
  end
end
