# frozen_string_literal: true

RSpec.describe RiskReviewActionItem, type: :model do
  context 'enums' do
    it { is_expected.to define_enum_for(:action_type).with_values(technical_change: 0, permissions_update: 1, customer_alignment: 2, internal_process_change: 3, cadences_change: 4, internal_comunication_change: 5) }
  end

  context 'associations' do
    it { is_expected.to belong_to(:risk_review) }
    it { is_expected.to belong_to(:membership) }
  end

  context 'validations' do
    it { is_expected.to validate_presence_of :risk_review }
    it { is_expected.to validate_presence_of :membership }
    it { is_expected.to validate_presence_of :created_date }
    it { is_expected.to validate_presence_of :action_type }
    it { is_expected.to validate_presence_of :description }
    it { is_expected.to validate_presence_of :deadline }
  end
end
