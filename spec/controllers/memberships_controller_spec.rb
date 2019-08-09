# frozen_string_literal: true

RSpec.describe MembershipsController, type: :controller do
  context 'unauthenticated' do
    describe 'GET #new' do
      before { get :new, params: { company_id: 'bar', team_id: 'foo' } }

      it { expect(response).to redirect_to new_user_session_path }
    end

    describe 'POST #create' do
      before { post :create, params: { company_id: 'bar', team_id: 'foo' } }

      it { expect(response).to redirect_to new_user_session_path }
    end

    describe 'GET #edit' do
      before { get :edit, params: { company_id: 'xpto', team_id: 'bar', id: 'foo' } }

      it { expect(response).to redirect_to new_user_session_path }
    end

    describe 'PUT #update' do
      before { put :update, params: { company_id: 'xpto', team_id: 'bar', id: 'foo' } }

      it { expect(response).to redirect_to new_user_session_path }
    end

    describe 'DELETE #destroy' do
      before { delete :destroy, params: { company_id: 'xpto', team_id: 'bar', id: 'foo' } }

      it { expect(response).to redirect_to new_user_session_path }
    end
  end

  context 'authenticated' do
    let(:plan) { Fabricate :plan, plan_type: :gold }
    let(:user) { Fabricate :user, first_name: 'zzz' }
    let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true, finish_at: 1.week.from_now }

    before { sign_in user }

    let(:company) { Fabricate :company, users: [user] }
    let(:team) { Fabricate :team, company: company }

    let!(:team_member) { Fabricate :team_member, company: company }
    let!(:other_team_member) { Fabricate :team_member, company: company }

    let!(:membership) { Fabricate :membership, team: team, team_member: team_member }
    let!(:other_membership) { Fabricate :membership, team: team }

    describe 'GET #new' do
      context 'valid parameters' do
        before { get :new, params: { company_id: company, team_id: team }, xhr: true }

        it 'instantiates a new Team Member and renders the template' do
          expect(response).to render_template 'memberships/new.js.erb'
          expect(assigns(:team_members)).to eq [other_team_member]
          expect(assigns(:membership)).to be_a_new Membership
        end
      end

      context 'invalid parameters' do
        context 'non-existent company' do
          before { get :new, params: { company_id: 'foo', team_id: team }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end

        context 'not-permitted company' do
          let(:company) { Fabricate :company, users: [] }

          before { get :new, params: { company_id: company, team_id: team }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end
      end
    end

    describe 'POST #create' do
      let!(:new_team_member) { Fabricate :team_member, company: company }

      context 'passing valid parameters' do
        before { post :create, params: { company_id: company, team_id: team, membership: { member_role: 'client', team_member_id: new_team_member.id } }, xhr: true }

        it 'creates the new team member and redirects to team show' do
          expect(response).to render_template 'memberships/create.js.erb'
          expect(assigns(:membership).errors.full_messages).to eq []
          expect(assigns(:membership)).to be_persisted
          expect(assigns(:membership).team).to eq team
          expect(assigns(:membership).team_member).to eq new_team_member
          expect(assigns(:membership).member_role).to eq 'client'
          expect(assigns(:memberships)).to eq team.reload.memberships.sort_by(&:team_member_name)
        end
      end

      context 'passing invalid parameters' do
        before { post :create, params: { company_id: company, team_id: team, membership: { team_member_id: '', member_role: nil } }, xhr: true }

        it 'does not create the team member and re-render the template with the errors' do
          expect(Membership.all.count).to eq 2
          expect(response).to render_template 'memberships/create.js.erb'
          expect(assigns(:membership).errors.full_messages).to eq ['Team member não pode ficar em branco']
        end
      end
    end

    describe 'GET #edit' do
      let(:team) { Fabricate :team, company: company }

      let!(:team_member) { Fabricate :team_member, company: company }
      let!(:other_team_member) { Fabricate :team_member, company: company }

      let(:membership) { Fabricate :membership, team: team, team_member: team_member }

      context 'valid parameters' do
        before { get :edit, params: { company_id: company.id, team_id: team, id: membership }, xhr: true }

        it 'assigns the instance variables and renders the template' do
          expect(response).to render_template 'memberships/edit.js.erb'
          expect(assigns(:company)).to eq company
          expect(assigns(:membership)).to eq membership
          expect(assigns(:team_members)).to eq [other_team_member]
          expect(assigns(:memberships)).to eq team.reload.memberships.sort_by(&:team_member_name)
        end
      end

      context 'invalid' do
        context 'membership' do
          before { get :edit, params: { company_id: company, team_id: team, id: 'foo' }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end

        context 'company' do
          context 'non-existent' do
            before { get :edit, params: { company_id: 'foo', team_id: team, id: membership }, xhr: true }

            it { expect(response).to have_http_status :not_found }
          end

          context 'not-permitted' do
            let(:company) { Fabricate :company, users: [] }

            before { get :edit, params: { company_id: company, team_id: team, id: membership }, xhr: true }

            it { expect(response).to have_http_status :not_found }
          end
        end
      end
    end

    describe 'PUT #update' do
      let(:team) { Fabricate :team, company: company }
      let(:other_team) { Fabricate :team, company: company }

      let(:team_member) { Fabricate :team_member, company: company }
      let(:other_team_member) { Fabricate :team_member, company: company }

      let!(:membership) { Fabricate :membership, team: team, team_member: team_member }

      context 'passing valid parameters' do
        before { put :update, params: { company_id: company, team_id: team, id: membership, membership: { member_role: :manager, team_member_id: other_team_member.id } }, xhr: true }

        it 'updates the member and redirects to team show' do
          membership_updated = membership.reload
          expect(membership_updated.member_role).to eq 'manager'
          expect(membership_updated.team_member).to eq other_team_member
          expect(assigns(:memberships)).to eq team.reload.memberships.sort_by(&:team_member_name)
          expect(response).to render_template 'memberships/update.js.erb'
        end
      end

      context 'passing invalid' do
        context 'team member parameters' do
          before { put :update, params: { company_id: company, team_id: team, id: membership, membership: { member_role: '', team_member_id: nil } }, xhr: true }

          it 'does not update the member and re-render the template with the errors' do
            expect(response).to render_template 'memberships/update.js.erb'
            expect(assigns(:membership).errors.full_messages).to eq ['Team member não pode ficar em branco']
          end
        end

        context 'non-existent membership' do
          before { put :update, params: { company_id: company, team_id: team, id: 'foo', membership: { member_role: :manager, team_member_id: other_team_member.id } }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end

        context 'unpermitted company' do
          let(:company) { Fabricate :company, users: [] }

          before { put :update, params: { company_id: company, team_id: team, id: membership, membership: { member_role: :manager, team_member_id: other_team_member.id } }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end
      end
    end

    describe 'DELETE #destroy' do
      let(:team) { Fabricate :team, company: company }

      context 'with valid data' do
        it 'deletes the member and renders the template' do
          delete :destroy, params: { company_id: company, team_id: team, id: membership }, xhr: true

          expect(Membership.all.count).to eq 1
          expect(response).to render_template 'memberships/destroy.js.erb'
        end
      end

      context 'with invalid' do
        context 'non-existent membership' do
          before { delete :destroy, params: { company_id: company, team_id: team, id: 'foo' }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end

        context 'unpermitted company' do
          let(:company) { Fabricate :company, users: [] }

          before { delete :destroy, params: { company_id: company, team_id: team, id: membership }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end
      end
    end
  end
end