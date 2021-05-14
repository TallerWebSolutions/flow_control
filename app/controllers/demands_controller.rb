# frozen_string_literal: true

class DemandsController < DemandsListController
  protect_from_forgery except: %i[search_demands]

  before_action :user_gold_check

  before_action :assign_company
  before_action :assign_demand, only: %i[edit update show synchronize_jira destroy destroy_physically score_research]
  before_action :assign_project, except: %i[demands_csv search_demands show destroy destroy_physically score_research index demands_list_by_ids demands_charts]

  def new
    @demand = Demand.new(project: @project)
  end

  def create
    @demand = Demand.new(demand_params.merge(project: @project, company: @company))
    return render :new unless @demand.save

    redirect_to company_demand_path(@company, @demand)
  end

  def destroy
    @demand.discard
    assign_dates_to_query
    build_demands_list
    assign_consolidations

    respond_to { |format| format.js { render 'demands/search_demands' } }
  end

  def edit
    build_demands_list

    respond_to { |format| format.js { render 'demands/edit' } }
  end

  def update
    @demand.update(demand_params)
    build_demands_list
    build_demands_objects

    if @demand.valid?
      flash[:notice] = I18n.t('general.updated.success')
      respond_to { |format| format.js { render 'demands/update' } }
    else
      flash[:error] = "#{I18n.t('general.updated.error')} | #{@demand.errors.full_messages.join(' | ')}"
    end
  end

  def show
    @demand_blocks = @demand.demand_blocks.includes([:blocker]).includes([:unblocker]).includes([:stage]).order(:block_time)
    @paged_demand_blocks = @demand_blocks.page(params[:page])
    @demand_transitions = @demand.demand_transitions.includes([:stage]).order(:last_time_in)
    @demand_comments = @demand.demand_comments.includes([:team_member]).order(:comment_date)

    compute_flow_efficiency
    compute_stream_percentages
    lead_time_breakdown
  end

  def index
    @demands = @company.demands.order('end_date DESC, commitment_date DESC, created_date DESC')
    @paged_demands = @demands.page(page_param)
    @demands_ids = @demands.map(&:id)

    assign_dates_to_query
    assign_consolidations
  end

  def synchronize_jira
    jira_account = @company.jira_accounts.first
    demand_url = company_project_demand_url(@demand.project.company, @demand.project, @demand)
    Jira::ProcessJiraIssueJob.perform_later(jira_account, @project, @demand.external_id, current_user.email, current_user.full_name, demand_url)
    flash[:notice] = I18n.t('general.enqueued')
    redirect_to company_demand_path(@company, @demand)
  end

  def demands_csv
    build_demands_list
    @demands_in_csv = @demands.kept.order(end_date: :desc)
    attributes = %w[id portfolio_unit current_stage project_id external_id demand_title demand_type class_of_service demand_score effort_downstream effort_upstream created_date commitment_date end_date]
    demands_csv = CSV.generate(headers: true) do |csv|
      csv << attributes
      @demands_in_csv.each { |demand| csv << demand.csv_array }
    end
    respond_to { |format| format.csv { send_data demands_csv, filename: "demands-#{Time.zone.now}.csv" } }
  end

  def search_demands
    assign_dates_to_query

    @demands = query_demands
    @demands = @demands.order(params[:order_by] => order_direction) if params[:order_by].present?

    @paged_demands = @demands.page(page_param)

    assign_consolidations

    render 'demands/index'
  end

  def destroy_physically
    flash[:error] = @demand.errors.full_messages.join(',') unless @demand.destroy

    respond_to { |format| format.js { render 'demands/destroy_physically' } }
  end

  def score_research
    ScoreMatrix.create(product: @demand.product) if @demand.product.score_matrix.blank?

    @demand_score_matrix = DemandScoreMatrix.new(user: current_user, demand: @demand)
    @percentage_answered = DemandScoreMatrixService.instance.percentage_answered(@demand)
    @current_position_in_backlog = "#{DemandScoreMatrixService.instance.current_position_in_backlog(@demand)}º"
    @backlog_total = DemandScoreMatrixService.instance.demands_list(@demand).count

    render 'demands/score_matrix/score_research'
  end

  def demands_list_by_ids
    @demands = []
    build_search_for_demands if object_type.present? && params[:object_id].present?

    @paged_demands = @demands.page(page_param) if @demands.present?

    assign_consolidations

    render 'demands/index'
  end

  def demands_charts
    @demands = query_demands.finished_with_leadtime.order(:end_date)
    min_date_demands = @demands.map(&:end_date).min || Time.zone.now
    max_date_demands = @demands.map(&:end_date).max || Time.zone.now

    start_date = [min_date_demands, (max_date_demands - 6.months)].max

    @demands_chart_adapter = Highchart::DemandsChartsAdapter.new(@demands, start_date, Time.zone.today.end_of_week, 'week')
  end

  private

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/MethodLength
  def build_search_for_demands
    demandable = object_type.constantize.find(object_id)

    @demand_fitness = params[:demand_fitness]
    @demand_state = params[:demand_state]
    @demand_type = if params[:demand].present?
                     demand_params[:demand_type]
                   else
                     params[:demand_type]
                   end

    @demands = if @demand_fitness == 'overserved'
                 demandable.overserved_demands[:value].kept
               elsif @demand_fitness == 'underserved'
                 demandable.underserved_demands[:value].kept
               elsif @demand_fitness == 'f4p'
                 demandable.fit_for_purpose_demands[:value].kept
               elsif @demand_state == 'discarded'
                 demandable.demands.discarded
               elsif @demand_type.present?
                 demandable.demands.where(demand_type: @demand_type).kept
               elsif @demand_state == 'delivered'
                 demandable.demands.kept.finished
               elsif @demand_state == 'backlog'
                 Demand.where(id: demandable.demands.not_started.map(&:id)).kept
               elsif @demand_state == 'upstream'
                 Demand.where(id: demandable.upstream_demands.map(&:id)).kept
               elsif @demand_state == 'downstream'
                 demandable.demands.in_wip.kept
               elsif @demand_state == 'unscored'
                 demandable.demands.unscored_demands.kept
               else
                 demandable.demands.kept
               end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/MethodLength

  def object_id
    @object_id ||= params[:object_id]&.to_s || @company.id
  end

  def object_type
    @object_type ||= params[:object_type] || 'Company'
  end

  def order_direction
    return 'asc' if params[:order_direction].blank?

    params[:order_direction]
  end

  def build_demands_objects
    @demands_ids = @paged_demands.map(&:id)
    @demands = @paged_demands.except(:limit, :offset)
    @unscored_demands = @project.demands.unscored_demands.order(external_id: :asc)
  end

  def compute_flow_efficiency
    @queue_percentage = Stats::StatisticsService.instance.compute_percentage(@demand.total_queue_time, @demand.total_touch_time)
    @touch_percentage = 100 - @queue_percentage
  end

  def compute_stream_percentages
    @upstream_percentage = Stats::StatisticsService.instance.compute_percentage(@demand.effort_upstream, @demand.effort_downstream)
    @downstream_percentage = 100 - @upstream_percentage
  end

  def build_demands_list
    @demands = []
    build_search_for_demands

    @paged_demands = @demands.page(page_param) if @demands.present?
  end

  def query_demands
    build_demands_list
    DemandService.instance.search_engine(@demands, params[:demands_start_date], params[:demands_end_date], params[:search_text], params[:demand_state], params[:demand_type], params[:class_of_service], params[:search_demand_tags]&.split(' '), params[:team_id])
  end

  def demand_params
    params.require(:demand).permit(:team_id, :product_id, :customer_id, :external_id, :demand_type, :downstream, :manual_effort, :class_of_service, :effort_upstream, :effort_downstream, :created_date, :commitment_date, :end_date, :demand_score, :external_url, :object_type, :object_id, :demand_state, :demand_fitness)
  end

  def assign_project
    @project = Project.find(params[:project_id])
  end

  def assign_demand
    @demand = @company.demands.friendly.find(params[:id]&.downcase)
  end

  def lead_time_breakdown
    @lead_time_breakdown ||= DemandService.instance.lead_time_breakdown([@demand])
  end

  def assign_dates_to_query
    @start_date = start_date_to_query
    @end_date = end_date_to_query
  end

  def start_date_to_query
    params['start_date'].to_date if params['start_date'].present?
  end

  def end_date_to_query
    params['end_date'].to_date if params['end_date'].present?
  end
end
