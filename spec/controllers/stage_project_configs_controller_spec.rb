# frozen_string_literal: true

RSpec.describe StageProjectConfigsController, type: :controller do
  context 'unauthenticated' do
    describe 'GET #edit' do
      before { get :edit, params: { company_id: 'xpto', stage_id: 'foo', id: 'bar' } }

      it { expect(response).to redirect_to new_user_session_path }
    end

    describe 'PUT #update' do
      before { put :update, params: { company_id: 'xpto', stage_id: 'foo', id: 'bar' } }

      it { expect(response).to redirect_to new_user_session_path }
    end
  end

  context 'authenticated' do
    let(:plan) { Fabricate :plan, plan_type: :gold }
    let(:user) { Fabricate :user }
    let!(:user_plan) { Fabricate :user_plan, user: user, plan: plan, active: true, paid: true, finish_at: 1.week.from_now }

    let(:company) { Fabricate :company, users: [user] }
    let(:stage) { Fabricate :stage, company: company }
    let(:customer) { Fabricate :customer, company: company }
    let(:project) { Fabricate :project, customers: [customer] }

    before { sign_in user }

    describe 'GET #edit' do
      let!(:stage_project_config) { Fabricate :stage_project_config, stage: stage, project: project }

      context 'passing valid IDs' do
        it 'assigns the instance variable and renders the template' do
          get :edit, params: { company_id: company, stage_id: stage, id: stage_project_config }
          expect(response).to render_template :edit
          expect(assigns(:company)).to eq company
          expect(assigns(:stage)).to eq stage
          expect(assigns(:stage_project_config)).to eq stage_project_config
        end
      end

      context 'passing an invalid' do
        context 'non-existent stage_project_config' do
          before { get :edit, params: { company_id: company, stage_id: stage, id: 'foo' } }

          it { expect(response).to have_http_status :not_found }
        end

        context 'non-existent stage' do
          before { get :edit, params: { company_id: company, stage_id: 'foo', id: stage_project_config } }

          it { expect(response).to have_http_status :not_found }
        end

        context 'non-existent company' do
          before { get :edit, params: { company_id: 'foo', stage_id: stage, id: stage_project_config } }

          it { expect(response).to have_http_status :not_found }
        end

        context 'not permitted' do
          let(:company) { Fabricate :company, users: [] }

          before { get :edit, params: { company_id: company, stage_id: stage, id: stage_project_config } }

          it { expect(response).to have_http_status :not_found }
        end
      end
    end

    describe 'PUT #update' do
      let!(:stage_project_config) { Fabricate :stage_project_config, stage: stage, project: project }

      let(:other_project) { Fabricate :project, customers: [customer] }
      let!(:other_stage_project_config) { Fabricate :stage_project_config, stage: stage, project: other_project }

      context 'with valid parameters' do
        context 'with replication to other projects' do
          it 'updates the config and replicates the values to the other projects' do
            put :update, params: { company_id: company, stage_id: stage, id: stage_project_config, replicate_to_projects: '1', max_time_in_stage: 1, max_time_in_stage_period: 'week', stage_project_config: { compute_effort: true, stage_percentage: 10, pairing_percentage: 20, management_percentage: 30 } }
            expect(response).to redirect_to edit_company_stage_stage_project_config_path(company, stage, stage_project_config)

            stage_project_config_updated = stage_project_config.reload
            expect(stage_project_config_updated.compute_effort?).to be true
            expect(stage_project_config_updated.stage_percentage).to eq 10.0
            expect(stage_project_config_updated.pairing_percentage).to eq 20.0
            expect(stage_project_config_updated.management_percentage).to eq 30.0
            expect(stage_project_config_updated.max_seconds_in_stage).to eq 604_800

            other_stage_project_config_updated = other_stage_project_config.reload
            expect(other_stage_project_config_updated.compute_effort?).to be true
            expect(other_stage_project_config_updated.stage_percentage).to eq 10.0
            expect(other_stage_project_config_updated.pairing_percentage).to eq 20.0
            expect(other_stage_project_config_updated.management_percentage).to eq 30.0
          end
        end

        context 'with max_time_in_stage_period as day' do
          it 'updates the config and replicates the values to the other projects' do
            put :update, params: { company_id: company, stage_id: stage, id: stage_project_config, replicate_to_projects: '1', max_time_in_stage: 1, max_time_in_stage_period: 'day', stage_project_config: { compute_effort: true, stage_percentage: 10, pairing_percentage: 20, management_percentage: 30 } }
            expect(response).to redirect_to edit_company_stage_stage_project_config_path(company, stage, stage_project_config)

            stage_project_config_updated = stage_project_config.reload
            expect(stage_project_config_updated.max_seconds_in_stage).to eq 86_400
          end
        end

        context 'without replication to other projects' do
          it 'updates the config and does not replicate the values to the other projects' do
            put :update, params: { company_id: company, stage_id: stage, id: stage_project_config, replicate_to_projects: '0', stage_project_config: { compute_effort: true, stage_percentage: 10, pairing_percentage: 20, management_percentage: 30 } }
            expect(response).to redirect_to edit_company_stage_stage_project_config_path(company, stage, stage_project_config)

            stage_project_config_updated = stage_project_config.reload
            expect(stage_project_config_updated.compute_effort?).to be true
            expect(stage_project_config_updated.stage_percentage).to eq 10.0
            expect(stage_project_config_updated.pairing_percentage).to eq 20.0
            expect(stage_project_config_updated.management_percentage).to eq 30.0
            expect(stage_project_config_updated.max_seconds_in_stage).to eq 0

            other_stage_project_config_updated = other_stage_project_config.reload
            expect(other_stage_project_config_updated.compute_effort?).to be true
            expect(other_stage_project_config_updated.stage_percentage).to eq other_stage_project_config.stage_percentage
            expect(other_stage_project_config_updated.pairing_percentage).to eq other_stage_project_config.pairing_percentage
            expect(other_stage_project_config_updated.management_percentage).to eq other_stage_project_config.management_percentage
          end
        end

        context 'nil stage_project_config params' do
          before { put :update, params: { company_id: company, stage_id: stage, id: stage_project_config, stage_project_config: { compute_effort: true, stage_percentage: nil, pairing_percentage: nil, management_percentage: nil } } }

          it 'save the model with the default informations' do
            stage_project_config_updated = stage_project_config.reload
            expect(stage_project_config_updated.compute_effort?).to be true
            expect(stage_project_config_updated.stage_percentage).to eq 0
            expect(stage_project_config_updated.pairing_percentage).to eq 0
            expect(stage_project_config_updated.management_percentage).to eq 0
            expect(stage_project_config_updated.max_seconds_in_stage).to eq 0

            expect(response).to redirect_to edit_company_stage_stage_project_config_path(company, stage, stage_project_config)
          end
        end
      end

      context 'passing invalid' do
        context 'company' do
          before { put :update, params: { company_id: 'foo', stage_id: stage, id: stage_project_config, stage_project_config: { compute_effort: true, stage_percentage: 10, pairing_percentage: 20, management_percentage: 30 } } }

          it { expect(response).to have_http_status :not_found }
        end

        context 'stage' do
          before { put :update, params: { company_id: company, stage_id: 'foo', id: stage_project_config, stage_project_config: { compute_effort: true, stage_percentage: 10, pairing_percentage: 20, management_percentage: 30 } } }

          it { expect(response).to have_http_status :not_found }
        end

        context 'stage_project_config' do
          before { put :update, params: { company_id: company, stage_id: stage, id: 'foo', stage_project_config: { compute_effort: true, stage_percentage: 10, pairing_percentage: 20, management_percentage: 30 } } }

          it { expect(response).to have_http_status :not_found }
        end
      end
    end
  end
end
