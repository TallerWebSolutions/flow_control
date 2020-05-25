# frozen_string_literal: true

class DemandScoreMatricesController < AuthenticatedController
  def create
    create_answers

    redirect_to score_research_company_demand_path(@demand.company, @demand)
  end

  def create_from_sheet
    create_answers

    redirect_to score_matrix_path(@demand.product.score_matrix)
  end

  def destroy
    destroy_answer

    @new_demand_score_matrix = DemandScoreMatrix.new

    update_demand_score

    respond_to { |format| format.js { render 'demand_score_matrices/destroy' } }
  end

  def destroy_from_sheet
    destroy_answer

    @new_demand_score_matrix = DemandScoreMatrix.new

    update_demand_score

    redirect_to score_matrix_path(@demand.product.score_matrix)
  end

  private

  def destroy_answer
    @demand_score_matrix = DemandScoreMatrix.find(params[:id])
    @demand = @demand_score_matrix.demand
    @demand_score_matrix.destroy
  end

  def create_answers
    @demand = Demand.find(params[:demand_id])

    answers = read_answers_in_params

    answers.each { |answer_id| DemandScoreMatrix.create(user: current_user, demand: @demand, score_matrix_answer_id: answer_id) }

    update_demand_score
  end

  def update_demand_score
    final_score = DemandScoreMatrixService.instance.compute_score(@demand)

    @demand.update(demand_score: final_score)

    @percentage_answered = DemandScoreMatrixService.instance.percentage_answered(@demand)
  end

  def read_answers_in_params
    answers = []

    params.each do |param|
      next unless param[0].start_with?('score_matrix_question_')

      answers << param[1] if param[1].to_i.positive?
    end

    answers
  end
end
