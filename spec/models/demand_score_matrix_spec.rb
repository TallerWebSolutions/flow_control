# frozen_string_literal: true

RSpec.describe DemandScoreMatrix, type: :model do
  context 'associations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :demand }
    it { is_expected.to belong_to :score_matrix_answer }
  end

  context 'validations' do
    context 'simple ones' do
      it { is_expected.to validate_presence_of :user }
      it { is_expected.to validate_presence_of :demand }
      it { is_expected.to validate_presence_of :score_matrix_answer }
    end

    context 'complex ones' do
      let(:user) { Fabricate :user }
      let(:demand) { Fabricate :demand }
      let(:score_matrix_answer) { Fabricate :score_matrix_answer }

      let!(:demand_score_matrix) { Fabricate :demand_score_matrix, user: user, demand: demand, score_matrix_answer: score_matrix_answer }
      let!(:duplicated_demand_score_matrix) { Fabricate.build :demand_score_matrix, user: user, demand: demand, score_matrix_answer: score_matrix_answer }
      let!(:diff_user_demand_score_matrix) { Fabricate.build :demand_score_matrix, demand: demand, score_matrix_answer: score_matrix_answer }
      let!(:diff_demand_demand_score_matrix) { Fabricate.build :demand_score_matrix, user: user, score_matrix_answer: score_matrix_answer }
      let!(:diff_answer_demand_score_matrix) { Fabricate.build :demand_score_matrix, demand: demand, user: user }

      it 'invalidates the duplicated data' do
        expect(duplicated_demand_score_matrix.valid?).to be false
        expect(duplicated_demand_score_matrix.errors[:demand]).to eq [I18n.t('activerecord.errors.models.demand_score_matrix.uniqueness')]
      end

      it { expect(diff_user_demand_score_matrix.valid?).to be true }
      it { expect(diff_demand_demand_score_matrix.valid?).to be true }
      it { expect(diff_answer_demand_score_matrix.valid?).to be true }
    end
  end
end
