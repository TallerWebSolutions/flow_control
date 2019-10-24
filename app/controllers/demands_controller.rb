# frozen_string_literal: true

class DemandsController < AuthenticatedController
  protect_from_forgery except: %i[demands_tab search_demands]

  before_action :user_gold_check

  before_action :assign_company
  before_action :assign_demand, only: %i[edit update show synchronize_jira destroy destroy_physically]
  before_action :assign_project, except: %i[demands_csv demands_tab search_demands show destroy destroy_physically]

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
    @demands = demands.order('demands.end_date DESC, demands.commitment_date DESC, demands.created_date DESC').page(page_param)
    @unpaged_demands = @demands.except(:limit, :offset)
    assign_consolidations

    respond_to { |format| format.js { render 'demands/search_demands' } }
  end

  def edit
    @demands = demands.order('demands.end_date DESC, demands.commitment_date DESC, demands.created_date DESC').page(page_param)
    @demands_ids = @demands.map(&:id)

    respond_to { |format| format.js { render 'demands/edit' } }
  end

  def update
    @demand.update(demand_params)
    @demands = demands.order('demands.end_date DESC, demands.commitment_date DESC, demands.created_date DESC').page(page_param)
    @demands_ids = @demands.map(&:id)
    @unpaged_demands = @demands.except(:limit, :offset)
    @unscored_demands = @project.demands.unscored_demands.order(external_id: :asc)

    respond_to { |format| format.js { render 'demands/update' } }
  end

  def show
    @demand_blocks = @demand.demand_blocks.order(:block_time)
    @demand_transitions = @demand.demand_transitions.order(:last_time_in)
    @queue_percentage = Stats::StatisticsService.instance.compute_percentage(@demand.total_queue_time, @demand.total_touch_time)
    @touch_percentage = 100 - @queue_percentage
    @upstream_percentage = Stats::StatisticsService.instance.compute_percentage(@demand.effort_upstream, @demand.effort_downstream)
    @downstream_percentage = 100 - @upstream_percentage
    @demand_comments = @demand.demand_comments.order(:comment_date)
    lead_time_breakdown
  end

  def synchronize_jira
    jira_account = @company.jira_accounts.first
    demand_url = company_project_demand_url(@demand.project.company, @demand.project, @demand)
    Jira::ProcessJiraIssueJob.perform_later(jira_account, @project, @demand.external_id, current_user.email, current_user.full_name, demand_url)
    flash[:notice] = I18n.t('general.enqueued')
    redirect_to company_demand_path(@company, @demand)
  end

  def demands_csv
    @demands_in_csv = Demand.where(id: params['demands_ids'].split(',')).kept.order(end_date: :desc)
    attributes = %w[id current_stage project_id external_id demand_title demand_type class_of_service business_score effort_downstream effort_upstream created_date commitment_date end_date]
    demands_csv = CSV.generate(headers: true) do |csv|
      csv << attributes
      @demands_in_csv.each { |demand| csv << demand.csv_array }
    end
    respond_to { |format| format.csv { send_data demands_csv, filename: "demands-#{Time.zone.now}.csv" } }
  end

  def demands_tab
    assign_dates_to_query

    @discarded_demands = demands.discarded
    @demands = query_demands(@start_date, @end_date)
    @unpaged_demands = @demands.except(:limit, :offset)

    assign_consolidations

    respond_to { |format| format.js { render 'demands/demands_tab' } }
  end

  def search_demands
    assign_dates_to_query

    @demands = query_demands(@start_date, @end_date)
    @unpaged_demands = @demands.except(:limit, :offset)

    assign_consolidations

    respond_to { |format| format.js { render 'demands/search_demands' } }
  end

  def destroy_physically
    flash[:error] = @demand.errors.full_messages.join(',') unless @demand.destroy

    respond_to { |format| format.js { render 'demands/destroy_physically' } }
  end

  private

  def demands
    @demands ||= Demand.where(id: params[:demands_ids].split(',')).includes(:portfolio_unit).includes(:product)
  end

  def query_demands(start_date, end_date)
    demands_list_view = demands.kept.to_dates(start_date, end_date)
    demands_list_view = filter_text(demands_list_view)
    demands_list_view = build_flow_status_query(demands_list_view, params[:flow_status])
    demands_list_view = build_demand_type_query(demands_list_view, params[:demand_type])
    demands_list_view = build_class_of_service_query(demands_list_view, params[:demand_class_of_service])
    demands_list_view.order('demands.end_date DESC, demands.commitment_date DESC, demands.created_date DESC').page(page_param)
  end

  def demand_params
    params.require(:demand).permit(:team_id, :external_id, :demand_type, :downstream, :manual_effort, :class_of_service, :effort_upstream, :effort_downstream, :created_date, :commitment_date, :end_date, :business_score, :external_url)
  end

  def assign_project
    @project = Project.find(params[:project_id])
  end

  def assign_demand
    @demand = Demand.friendly.find(params[:id]&.downcase)
  end

  def lead_time_breakdown
    @lead_time_breakdown ||= DemandService.instance.lead_time_breakdown([@demand])
  end

  def build_flow_status_query(demands, params_flow_status)
    filtered_demands = demands
    filtered_demands = filtered_demands.not_started if params_flow_status == 'not_started'
    filtered_demands = filtered_demands.in_wip if params_flow_status == 'wip'
    filtered_demands = filtered_demands.finished if params_flow_status == 'delivered'

    filtered_demands
  end

  def build_demand_type_query(demands, params_demand_type)
    return demands.where(demand_type: params_demand_type) if params_demand_type.present? && params_demand_type != 'all_types'

    demands
  end

  def build_class_of_service_query(demands, params_class_of_service)
    return demands.where(class_of_service: params_class_of_service) if params_class_of_service.present? && params_class_of_service != 'all_classes'

    demands
  end

  def filter_text(demands_list)
    return demands_list.includes(:project) if params[:search_text].blank?

    demands_list.includes(:project).joins(:project).where('demands.demand_title ILIKE :search_param OR demands.external_id ILIKE :search_param OR projects.name ILIKE :search_param', search_param: "%#{params[:search_text].downcase}%")
  end

  def assign_consolidations
    if @demands.present?
      @confidence_95_leadtime = Stats::StatisticsService.instance.percentile(95, @unpaged_demands.finished_with_leadtime.map(&:leadtime_in_days))
      @confidence_80_leadtime = Stats::StatisticsService.instance.percentile(80, @unpaged_demands.finished_with_leadtime.map(&:leadtime_in_days))
      @confidence_65_leadtime = Stats::StatisticsService.instance.percentile(65, @unpaged_demands.finished_with_leadtime.map(&:leadtime_in_days))
      build_flow_informations
    else
      @confidence_95_leadtime = 0
      @confidence_80_leadtime = 0
      @confidence_65_leadtime = 0
      @total_queue_time = 0
      @total_touch_time = 0
      @average_queue_time = 0
      @average_touch_time = 0
      @avg_work_hours_per_demand = 0
    end
  end

  def build_flow_informations
    @total_queue_time = @unpaged_demands.sum(&:total_queue_time).to_f / 1.hour
    @total_touch_time = @unpaged_demands.sum(&:total_touch_time).to_f / 1.hour
    @average_queue_time = @total_queue_time / @unpaged_demands.count
    @average_touch_time = @total_touch_time / @unpaged_demands.count
    @avg_work_hours_per_demand = @unpaged_demands.with_effort.sum(&:total_effort) / @unpaged_demands.count
    build_block_informations
  end

  def build_block_informations
    @share_demands_blocked = @unpaged_demands.count { |demand_list| demand_list.demand_blocks.count.positive? }.to_f / @unpaged_demands.count
  end

  def assign_dates_to_query
    @start_date = start_date_to_query
    @end_date = end_date_to_query
  end

  def start_date_to_query
    return params['start_date'].to_date if params['start_date'].present?

    3.months.ago.to_date
  end

  def end_date_to_query
    return params['end_date'].to_date if params['end_date'].present?

    Time.zone.today
  end
end
