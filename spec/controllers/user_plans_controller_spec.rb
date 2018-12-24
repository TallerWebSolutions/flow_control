# frozen_string_literal: true

RSpec.describe UserPlansController, type: :controller do
  context 'unauthenticated' do
    describe 'PATCH #activate_user_plan' do
      before { patch :activate_user_plan, params: { user_id: 'foo', id: 'bar' } }
      it { expect(response).to redirect_to new_user_session_path }
    end

    describe 'PATCH #deactivate_user_plan' do
      before { patch :deactivate_user_plan, params: { user_id: 'foo', id: 'bar' } }
      it { expect(response).to redirect_to new_user_session_path }
    end
  end

  context 'authenticated as admin' do
    let(:user) { Fabricate :user, admin: true }
    let(:plan) { Fabricate :plan }
    before { sign_in user }

    describe 'PATCH #activate_user_plan' do
      let(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: false }

      context 'valid params' do
        it 'activates the plan and redirects to the user profile' do
          patch :activate_user_plan, params: { user_id: user, id: user_plan }
          expect(UserPlan.last).to be_active
          expect(response).to redirect_to user_path(user)
        end
      end

      context 'invalid' do
        context 'user' do
          before { patch :activate_user_plan, params: { user_id: 'foo', id: user_plan } }
          it { expect(response).to have_http_status :not_found }
        end
        context 'user_plan' do
          before { patch :activate_user_plan, params: { user_id: user, id: 'foo' } }
          it { expect(response).to have_http_status :not_found }
        end
      end
    end

    describe 'PATCH #deactivate_user_plan' do
      let(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true }

      context 'valid params' do
        it 'deactivates the plan and redirects to the user profile' do
          patch :deactivate_user_plan, params: { user_id: user, id: user_plan }
          expect(UserPlan.last).not_to be_active
          expect(response).to redirect_to user_path(user)
        end
      end

      context 'invalid' do
        context 'user' do
          before { patch :deactivate_user_plan, params: { user_id: 'foo', id: user_plan } }
          it { expect(response).to have_http_status :not_found }
        end
        context 'user_plan' do
          before { patch :deactivate_user_plan, params: { user_id: user, id: 'foo' } }
          it { expect(response).to have_http_status :not_found }
        end
      end
    end

    describe 'PATCH #pay_plan' do
      let(:user_plan) { Fabricate :user_plan, user: user, plan: plan, paid: false }

      context 'valid params' do
        it 'deactivates the plan and redirects to the user profile' do
          patch :pay_plan, params: { user_id: user, id: user_plan }
          expect(UserPlan.last).to be_paid
          expect(response).to redirect_to user_path(user)
        end
      end

      context 'invalid' do
        context 'user' do
          before { patch :pay_plan, params: { user_id: 'foo', id: user_plan } }
          it { expect(response).to have_http_status :not_found }
        end
        context 'user_plan' do
          before { patch :pay_plan, params: { user_id: user, id: 'foo' } }
          it { expect(response).to have_http_status :not_found }
        end
      end
    end

    describe 'PATCH #unpay_plan' do
      let(:user_plan) { Fabricate :user_plan, user: user, plan: plan, paid: true }

      context 'valid params' do
        it 'deactivates the plan and redirects to the user profile' do
          patch :unpay_plan, params: { user_id: user, id: user_plan }
          expect(UserPlan.last).not_to be_paid
          expect(response).to redirect_to user_path(user)
        end
      end

      context 'invalid' do
        context 'user' do
          before { patch :unpay_plan, params: { user_id: 'foo', id: user_plan } }
          it { expect(response).to have_http_status :not_found }
        end
        context 'user_plan' do
          before { patch :unpay_plan, params: { user_id: user, id: 'foo' } }
          it { expect(response).to have_http_status :not_found }
        end
      end
    end
  end
end
