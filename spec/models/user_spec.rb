# frozen_string_literal: true

RSpec.describe User, type: :model do
  context 'associations' do
    it { is_expected.to have_many(:companies).through(:user_company_roles) }
    it { is_expected.to have_many(:user_company_roles) }
    it { is_expected.to have_many(:user_project_roles).dependent(:destroy) }
    it { is_expected.to have_many(:projects).through(:user_project_roles) }
    it { is_expected.to have_many(:demand_data_processments).dependent(:destroy) }
    it { is_expected.to have_many(:user_plans).dependent(:destroy) }
    it { is_expected.to have_one(:team_member).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:memberships).through(:team_member) }
    it { is_expected.to have_many(:item_assignments).through(:memberships) }
    it { is_expected.to have_many(:demands).through(:item_assignments) }
  end

  context 'validations' do
    it { is_expected.to validate_presence_of :first_name }
    it { is_expected.to validate_presence_of :last_name }
    it { is_expected.to validate_presence_of :email }
  end

  context 'scopes' do
    describe '.to_notify_email' do
      context 'having data' do
        let(:first_user) { Fabricate :user, email_notifications: true }
        let(:second_user) { Fabricate :user, email_notifications: true }
        let(:third_user) { Fabricate :user, email_notifications: false }

        it { expect(described_class.to_notify_email).to match_array [first_user, second_user] }
      end

      context 'having no data' do
        it { expect(described_class.to_notify_email).to eq [] }
      end
    end

    describe '.admins' do
      context 'having data' do
        let(:first_user) { Fabricate :user, admin: true }
        let(:second_user) { Fabricate :user, admin: true }
        let(:third_user) { Fabricate :user, admin: false }

        it { expect(described_class.admins).to match_array [first_user, second_user] }
      end

      context 'having no data' do
        it { expect(described_class.admins).to eq [] }
      end
    end
  end

  describe '#trial?' do
    context 'having no plans' do
      let(:plan) { Fabricate :plan, plan_type: :trial }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true, finish_at: Time.zone.yesterday }

      it { expect(user.trial?).to be false }
    end

    context 'when it is trial' do
      let(:plan) { Fabricate :plan, plan_type: :trial }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true }

      it { expect(user.trial?).to be true }
    end
  end

  describe '#lite?' do
    context 'having no plans' do
      let(:plan) { Fabricate :plan, plan_type: :lite }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: false }

      it { expect(user.lite?).to be false }
    end

    context 'when it is lite' do
      let(:plan) { Fabricate :plan, plan_type: :lite }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true }

      it { expect(user.lite?).to be true }
    end
  end

  describe '#gold?' do
    context 'having no plans' do
      let(:plan) { Fabricate :plan, plan_type: :gold }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: false }

      it { expect(user.gold?).to be false }
    end

    context 'when it is gold' do
      let(:plan) { Fabricate :plan, plan_type: :gold }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true }

      it { expect(user.gold?).to be true }
    end
  end

  describe '#no_plan?' do
    context 'having no plans' do
      let(:plan) { Fabricate :plan, plan_type: :lite }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: false }

      it { expect(user.no_plan?).to be true }
    end

    context 'when it is lite' do
      let(:plan) { Fabricate :plan, plan_type: :lite }
      let(:user) { Fabricate :user }
      let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true }

      it { expect(user.no_plan?).to be false }
    end
  end

  describe '#current_plan' do
    context 'having plans' do
      let(:user) { Fabricate :user }
      let(:plan) { Fabricate :plan }
      let!(:user_plan) { Fabricate :user_plan, plan: plan, user: user, active: true, paid: true }

      it { expect(user.current_plan).to eq plan }
    end

    context 'having no plans' do
      let(:user) { Fabricate :user }
      let(:plan) { Fabricate :plan }
      let!(:user_plan) { Fabricate :user_plan, plan: plan, user: user, active: false }

      it { expect(user.current_plan).to be_nil }
    end
  end

  describe '#current_user_plan' do
    context 'having plans' do
      let(:user) { Fabricate :user }
      let(:plan) { Fabricate :plan }
      let!(:user_plan) { Fabricate :user_plan, plan: plan, user: user, active: true, paid: true }

      it { expect(user.current_user_plan).to eq user_plan }
    end

    context 'having no plans' do
      let(:user) { Fabricate :user }
      let(:plan) { Fabricate :plan }
      let!(:user_plan) { Fabricate :user_plan, plan: plan, user: user, active: false, paid: false }

      it { expect(user.current_user_plan).to be_nil }
    end
  end

  describe '#toggle_admin' do
    context 'admin' do
      let(:user) { Fabricate :user, admin: true }

      before { user.toggle_admin }

      it { expect(user).not_to be_admin }
    end

    context 'not admin' do
      let(:user) { Fabricate :user, admin: false }

      before { user.toggle_admin }

      it { expect(user).to be_admin }
    end
  end

  describe '#full_name' do
    let(:user) { Fabricate :user }

    it { expect(user.full_name).to eq "#{user.first_name} #{user.last_name}" }
  end

  describe '#role_in_company' do
    let(:company) { Fabricate :company }
    let(:other_company) { Fabricate :company }

    let(:user) { Fabricate :user }
    let(:other_user) { Fabricate :user }

    let!(:user_company_role) { Fabricate :user_company_role, company: company, user: user, user_role: :manager }
    let!(:other_company_role) { Fabricate :user_company_role, company: other_company, user: user, user_role: :director }

    it { expect(user.role_in_company(company)).to eq user_company_role }
    it { expect(user.role_in_company(other_company)).to eq other_company_role }
  end

  describe '#managing_company?' do
    let(:company) { Fabricate :company }
    let(:other_company) { Fabricate :company }

    let(:user) { Fabricate :user }
    let(:other_user) { Fabricate :user }
    let(:ops_user) { Fabricate :user }

    let!(:user_company_role) { Fabricate :user_company_role, company: company, user: user, user_role: :manager }
    let!(:other_company_role) { Fabricate :user_company_role, company: other_company, user: user, user_role: :director }
    let!(:ops_company_role) { Fabricate :user_company_role, company: other_company, user: ops_user, user_role: :operations }

    it { expect(user.managing_company?(company)).to be true }
    it { expect(user.managing_company?(other_company)).to be true }
    it { expect(ops_user.managing_company?(other_company)).to be false }
  end
end
