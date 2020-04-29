# frozen_string_literal: true

# == Schema Information
#
# Table name: customers
#
#  id             :bigint           not null, primary key
#  name           :string           not null
#  products_count :integer          default(0)
#  projects_count :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  company_id     :integer          not null
#
# Indexes
#
#  index_customers_on_company_id           (company_id)
#  index_customers_on_company_id_and_name  (company_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_ef51a916ef  (company_id => companies.id)
#

class Customer < ApplicationRecord
  include ProjectAggregator
  include DemandsAggregator

  belongs_to :company, counter_cache: true
  has_many :products, dependent: :restrict_with_error
  has_many :demands, through: :products
  has_and_belongs_to_many :projects, dependent: :restrict_with_error
  has_and_belongs_to_many :devise_customers, dependent: :destroy

  validates :company, :name, presence: true
  validates :name, uniqueness: { scope: :company, message: I18n.t('customer.name.uniqueness') }

  def add_user(devise_customer)
    return if devise_customers.include?(devise_customer)

    devise_customers << devise_customer
  end
end
