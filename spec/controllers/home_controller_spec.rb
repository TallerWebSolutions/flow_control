# frozen_string_literal: true

RSpec.describe HomeController, type: :controller do
  context 'unauthenticated' do
    describe 'GET #show' do
      before { get :show }

      it { expect(response).to redirect_to new_user_session_path }
    end
  end

  context 'authenticated' do
    let(:user) { Fabricate :user }

    before { sign_in user }

    describe 'GET #show' do
      context 'no plan' do
        let(:plan) { Fabricate :plan, plan_type: :lite }
        let!(:user_plan) { Fabricate :user_plan, plan: plan, active: true, paid: true }

        before { get :show }

        it { expect(response).to redirect_to no_plan_path }
      end

      context 'inactive plan in the period' do
        let(:plan) { Fabricate :plan, plan_type: :lite }
        let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: false, paid: true }

        before { get :show }

        it { expect(response).to redirect_to user_path(user) }
      end

      context 'lite user' do
        let(:plan) { Fabricate :plan, plan_type: :lite }
        let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true }

        before { get :show }

        it { expect(response).to redirect_to request_project_information_path }
      end

      context 'gold user' do
        let(:plan) { Fabricate :plan, plan_type: :gold }
        let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true }

        let!(:company) { Fabricate :company, users: [user] }

        before { get :show }

        it { expect(response).to redirect_to user_path(user) }
      end
    end
  end
end
