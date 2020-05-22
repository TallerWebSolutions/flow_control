# frozen_string_literal: true

RSpec.describe DemandScoreMatricesController, type: :controller do
  context 'unauthenticated' do
    describe 'POST #create' do
      before { post :create, params: { demand_id: 'foo' } }

      it { expect(response).to redirect_to new_user_session_path }
    end

    describe 'DELETE #destroy' do
      before { delete :destroy, params: { id: 'foo' } }

      it { expect(response).to redirect_to new_user_session_path }
    end
  end

  context 'authenticated' do
    let(:user) { Fabricate :user }
    let(:product) { Fabricate :product }
    let!(:demand) { Fabricate :demand, product: product }

    before { sign_in user }

    describe 'POST #create' do
      context 'with valid data' do
        let(:score_matrix) { Fabricate :score_matrix, product: product }
        let(:first_question) { Fabricate :score_matrix_question, score_matrix: score_matrix, question_weight: 20 }
        let(:second_question) { Fabricate :score_matrix_question, score_matrix: score_matrix, question_weight: 10 }
        let(:third_question) { Fabricate :score_matrix_question, score_matrix: score_matrix, question_weight: 25 }

        let!(:first_answer) { Fabricate :score_matrix_answer, score_matrix_question: first_question, answer_value: 5 }
        let!(:second_answer) { Fabricate :score_matrix_answer, score_matrix_question: second_question, answer_value: 0 }
        let!(:third_answer) { Fabricate :score_matrix_answer, score_matrix_question: third_question, answer_value: 3 }

        let!(:first_demand_score_matrix) { Fabricate :demand_score_matrix, user: user, demand: demand, score_matrix_answer: first_answer }
        let!(:second_demand_score_matrix) { Fabricate :demand_score_matrix, user: user, demand: demand, score_matrix_answer: second_answer }

        before { post :create, params: { demand_id: demand.id, "score_matrix_question_#{first_question.id}" => first_answer.id, "score_matrix_question_#{second_question.id}" => second_answer.id } }

        it 'assigns the instance variable and renders the template' do
          expect(response).to redirect_to score_research_company_demand_path(demand.company, demand)
          expect(DemandScoreMatrix.count).to eq 2
          expect(DemandScoreMatrix.all.map(&:score_matrix_answer)).to match_array [first_answer, second_answer]
          expect(DemandScoreMatrix.all.map(&:user)).to match_array [user, user]
          expect(DemandScoreMatrix.all.map(&:demand)).to match_array [demand, demand]
        end
      end

      context 'with no data' do
        before { post :create, params: { demand_id: demand.id } }

        it 'assigns the instance variable and renders the template' do
          expect(response).to redirect_to score_research_company_demand_path(demand.company, demand)
          expect(DemandScoreMatrix.count).to eq 0
        end
      end

      context 'with invalid' do
        context 'demand id' do
          before { post :create, params: { demand_id: 'foo' } }

          it { expect(response).to have_http_status :not_found }
        end
      end
    end

    describe 'DELETE #destroy' do
      context 'with valid data' do
        let(:score_matrix) { Fabricate :score_matrix, product: product }
        let(:first_question) { Fabricate :score_matrix_question, score_matrix: score_matrix, question_weight: 20 }
        let(:second_question) { Fabricate :score_matrix_question, score_matrix: score_matrix, question_weight: 10 }
        let(:third_question) { Fabricate :score_matrix_question, score_matrix: score_matrix, question_weight: 25 }

        let!(:first_answer) { Fabricate :score_matrix_answer, score_matrix_question: first_question, answer_value: 5 }
        let!(:second_answer) { Fabricate :score_matrix_answer, score_matrix_question: second_question, answer_value: 0 }
        let!(:third_answer) { Fabricate :score_matrix_answer, score_matrix_question: third_question, answer_value: 3 }

        let!(:first_demand_score_matrix) { Fabricate :demand_score_matrix, user: user, demand: demand, score_matrix_answer: first_answer }
        let!(:second_demand_score_matrix) { Fabricate :demand_score_matrix, user: user, demand: demand, score_matrix_answer: second_answer }

        before { delete :destroy, params: { id: first_demand_score_matrix }, xhr: true }

        it 'assigns the instance variable and renders the template' do
          expect(response).to render_template 'demand_score_matrices/destroy'
          expect(assigns(:demand_score_matrix)).to eq first_demand_score_matrix
          expect(assigns(:new_demand_score_matrix)).to be_a_new DemandScoreMatrix
          expect(DemandScoreMatrix.count).to eq 1
        end
      end

      context 'with no data' do
        let!(:first_demand_score_matrix) { Fabricate :demand_score_matrix }

        before { delete :destroy, params: { id: first_demand_score_matrix }, xhr: true }

        it 'assigns the instance variable and renders the template' do
          expect(response).to render_template 'demand_score_matrices/destroy'
          expect(assigns(:demand_score_matrix)).to eq first_demand_score_matrix
          expect(assigns(:new_demand_score_matrix)).to be_a_new DemandScoreMatrix
          expect(DemandScoreMatrix.count).to eq 0
        end
      end

      context 'with invalid' do
        context 'score matrix' do
          before { delete :destroy, params: { id: 'foo' }, xhr: true }

          it { expect(response).to have_http_status :not_found }
        end
      end
    end
  end
end
