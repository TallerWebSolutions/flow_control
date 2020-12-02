# frozen_string_literal: true

class ProjectsController < AuthenticatedController
  before_action :user_gold_check

  before_action :assign_company
  before_action :assign_project, except: %i[new create index search_projects running_projects_charts]

  def show
    assign_project_stages
    assign_customer_projects
    assign_product_projects
    assign_projects_to_copy_stages_from
    assign_demands_ids

    @dashboard_project_consolidations = Consolidations::ProjectConsolidation.for_project(@project).weekly_data.after_date(10.weeks.ago).order(:consolidation_date)
    @all_project_consolidations = Consolidations::ProjectConsolidation.for_project(@project).weekly_data.order(:consolidation_date)

    @demands_chart_adapter = Highchart::DemandsChartsAdapter.new(@project.demands, @project.start_date, Time.zone.today, 'week')
    @demands_finished_with_leadtime = @project.demands.finished_with_leadtime
    @lead_time_histogram_data = Stats::StatisticsService.instance.leadtime_histogram_hash(@demands_finished_with_leadtime.map(&:leadtime))
    @status_report_data = Highchart::StatusReportChartsAdapter.new(@demands_finished_with_leadtime, @project.start_date, Time.zone.today, 'week')
    @last_10_deliveries = @project.demands.kept.finished.order(end_date: :desc).limit(10)
    @unscored_demands = @project.demands.unscored_demands.order(external_id: :asc)
    @demands_blocks = @project.demand_blocks.order(block_time: :desc)

    @ordered_project_risk_alerts = @project.project_risk_alerts.order(created_at: :desc)
    @project_change_deadline_histories = @project.project_change_deadline_histories.includes(:user)
    @inconsistent_demands = @project.demands.dates_inconsistent_to_project(@project)
  end

  def index
    @projects = @company.projects.distinct.includes(:team).order(end_date: :desc).page(page_param)
    @unpaged_projects = @projects.except(:limit, :offset)

    @projects_summary = ProjectsSummaryData.new(@unpaged_projects)
  end

  def new
    assign_customers
    @project = Project.new
  end

  def create
    @project = Project.new(project_params.merge(company: @company))
    return redirect_to company_projects_path(@company) if @project.save

    assign_customers
    render :new
  end

  def edit
    assign_customers
  end

  def update
    check_change_in_deadline!
    @project.update(project_params)

    return redirect_to company_project_path(@company, @project) if @project.save

    assign_customers
    render :edit
  end

  def destroy
    if @project.destroy
      flash[:notice] = I18n.t('project.destroy.success')
    else
      flash[:error] = "#{I18n.t('project.destroy.error')} - #{@project.errors.full_messages.join(' | ')}"
    end

    redirect_to company_projects_path(@company)
  end

  def finish_project
    ProjectsRepository.instance.finish_project!(@project)
    flash[:notice] = I18n.t('projects.finish_project.success_message')
    redirect_to company_project_path(@company, @project)
  end

  def statistics
    respond_to { |format| format.js { render 'projects/project_statistics' } }
  end

  def copy_stages_from
    @project_to_copy_stages_from = Project.find(params[:project_to_copy_stages_from])

    @project_to_copy_stages_from.stage_project_configs.each do |config|
      new_config = StageProjectConfig.find_or_initialize_by(stage: config.stage, project: @project)
      new_config.update(stage_percentage: config.stage_percentage, pairing_percentage: config.pairing_percentage, management_percentage: config.management_percentage,
                        max_seconds_in_stage: config.max_seconds_in_stage, compute_effort: config.compute_effort)
    end

    assign_project_stages

    respond_to { |format| format.js { render 'stages/update_stages_table' } }
  end

  def associate_customer
    customer = @company.customers.find(params[:customer_id])
    @project.add_customer(customer)
    assign_customer_projects
    respond_to { |format| format.js { render 'projects/associate_dissociate_customer' } }
  end

  def dissociate_customer
    customer = @company.customers.find(params[:customer_id])
    @project.remove_customer(customer)
    assign_customer_projects
    respond_to { |format| format.js { render 'projects/associate_dissociate_customer' } }
  end

  def associate_product
    product = @company.products.find(params[:product_id])
    @project.add_product(product)
    assign_product_projects
    respond_to { |format| format.js { render 'projects/associate_dissociate_product' } }
  end

  def dissociate_product
    product = @company.products.find(params[:product_id])
    @project.remove_product(product)
    assign_product_projects
    respond_to { |format| format.js { render 'projects/associate_dissociate_product' } }
  end

  def risk_drill_down
    @project_consolidations = @project.project_consolidations.order(:consolidation_date)
    respond_to { |format| format.js { render 'projects/risk_drill_down' } }
  end

  def closing_dashboard
    @project_summary = ProjectsSummaryData.new([@project])

    respond_to { |format| format.js { render 'projects/closing_info' } }
  end

  def status_report_dashboard
    @project_summary = ProjectsSummaryData.new([@project])
    @x_axis = TimeService.instance.weeks_between_of(@project.start_date.beginning_of_week, @project.end_date.end_of_week)
    @work_item_flow_information = Flow::WorkItemFlowInformations.new(@project.demands, @project.initial_scope, @x_axis.length, @x_axis.last)

    build_work_item_flow_information

    respond_to { |format| format.js { render 'projects/status_report_dashboard' } }
  end

  def lead_time_dashboard
    @project_consolidations = @project.project_consolidations.order(:consolidation_date)

    respond_to { |format| format.js { render 'projects/lead_time_dashboard' } }
  end

  def search_projects
    @target_name = params[:target_name]

    @projects = build_projects_search(projects_ids, params[:start_date], params[:end_date], params[:project_status], params[:project_name])
    @unpaged_projects = @projects.except(:limit, :offset)

    @projects_summary = ProjectsSummaryData.new(@unpaged_projects)

    respond_to { |format| format.js { render 'projects/search_projects' } }
  end

  def running_projects_charts
    @running_projects = @company.projects.running.order(:end_date)

    @running_projects_leadtime_data = {}
    @running_projects.each do |project|
      demands_chart_adapter = Highchart::DemandsChartsAdapter.new(project.demands, project.start_date, Time.zone.today, 'week')
      @running_projects_leadtime_data[project] = demands_chart_adapter
    end

    render 'projects/running_projects_charts'
  end

  def update_consolidations
    Consolidations::ProjectConsolidationJob.perform_later(@project)
    flash[:notice] = I18n.t('general.enqueued')

    redirect_to company_project_path(@company, @project)
  end

  def statistics_tab
    @all_project_consolidations = Consolidations::ProjectConsolidation.for_project(@project).weekly_data.order(:consolidation_date)
  end

  private

  def build_work_item_flow_information
    @x_axis.each_with_index do |analysed_date, distribution_index|
      add_data_to_chart = analysed_date <= Time.zone.today.end_of_week
      @work_item_flow_information.work_items_flow_behaviour(@x_axis.first, analysed_date, distribution_index, add_data_to_chart)
      @work_item_flow_information.build_cfd_hash(@x_axis.first, analysed_date)
    end
  end

  def build_projects_search(projects_ids, start_date, end_date, project_status, project_name)
    projects = Project.where(id: projects_ids)
    projects = projects.where('name ILIKE :name', name: "%#{project_name.tr(' ', '%')}%") if project_name.present?
    projects = projects.where(status: project_status) if project_status.present?
    projects = projects.where('start_date >= :start_date', start_date: start_date) if start_date.present?
    projects = projects.where('end_date <= :end_date', end_date: end_date) if end_date.present?
    projects.order(end_date: :desc).page(page_param)
  end

  def assign_demands_ids
    @demands_ids = @project.demands.map(&:id)
  end

  def assign_projects_to_copy_stages_from
    @projects_to_copy_stages_from = (@company.projects - [@project]).sort_by(&:name)
  end

  def assign_project_stages
    @stages_list = @project.reload.stages.order(:order, :name)
  end

  def project_params
    params.require(:project).permit(:name, :nickname, :status, :project_type, :start_date, :end_date, :value, :qty_hours, :hour_value, :initial_scope, :percentage_effort_to_bugs, :team_id, :max_work_in_progress)
  end

  def assign_project
    @project = @company.projects.includes(:team).find(params[:id])
  end

  def check_change_in_deadline!
    return if project_params[:end_date].blank? || @project.end_date == Date.parse(project_params[:end_date])

    ProjectChangeDeadlineHistory.create!(user: current_user, project: @project, previous_date: @project.end_date, new_date: project_params[:end_date])
  end

  def assign_customer_projects
    @project_customers = @project.customers.order(:name)
    @not_associated_customers = @company.customers - @project_customers
  end

  def assign_product_projects
    @project_products = @project.products.order(:name)
    @not_associated_products = @company.products - @project_products
  end
end
