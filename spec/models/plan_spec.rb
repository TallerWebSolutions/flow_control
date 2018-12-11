# frozen_string_literal: true

RSpec.describe Plan, type: :model do
  context 'enums' do
    it { is_expected.to define_enum_for(:plan_type).with(trial: 0, lite: 1, standard: 2, gold: 3) }
  end

  context 'associations' do
    it { is_expected.to have_many(:user_plans).dependent(:destroy) }
  end

  context 'validations' do
    it { is_expected.to validate_presence_of :plan_type }
    it { is_expected.to validate_presence_of :max_number_of_downloads }
    it { is_expected.to validate_presence_of :plan_value }
  end
end