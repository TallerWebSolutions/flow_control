# frozen_string_literal: true

class FlowImpactsController < AuthenticatedController
  before_action :assign_company
  before_action :assign_project, except: %i[new_direct_link create_direct_link]

  def new
    @flow_impact = FlowImpact.new
    @demands_for_impact_form = @project.demands.in_wip.order(:demand_id)
    render 'flow_impacts/new.js.erb'
  end

  def create
    @flow_impact = FlowImpact.new(flow_impact_params.merge(project: @project))
    @flow_impact.save
    @flow_impacts = @project.flow_impacts.order(:start_date)
    @demands_for_impact_form = @project.demands.in_wip
    render 'flow_impacts/create.js.erb'
  end

  def destroy
    @flow_impact = FlowImpact.find(params[:id])
    @flow_impact.destroy
    @flow_impacts = @project.flow_impacts.order(:start_date)
    render 'flow_impacts/destroy.js.erb'
  end

  def flow_impacts_tab
    @flow_impacts = @project.flow_impacts.order(:start_date)
    respond_to { |format| format.js { render 'flow_impacts/flow_impacts_tab' } }
  end

  def new_direct_link
    @flow_impact = FlowImpact.new
    @projects_to_direct_link = @company.projects.running
    @demands_to_direct_link = []
  end

  def create_direct_link
    @flow_impact = FlowImpact.new(flow_impact_direct_link_params)
    if @flow_impact.save
      flash[:notice] = I18n.t('flow_impacts.create.success')
    else
      flash[:error] = @flow_impact.errors.full_messages.join(' | ')
    end

    redirect_to new_direct_link_company_flow_impacts_path(@company)
  end

  def demands_to_project
    project = @company.projects.find(params[:project_id])
    @demands_to_project = project.demands.in_wip.order(:demand_id)

    render 'flow_impacts/demands_to_project.js.erb'
  end

  private

  def flow_impact_params
    params.require(:flow_impact).permit(:demand_id, :start_date, :end_date, :impact_description, :impact_type)
  end

  def flow_impact_direct_link_params
    params.require(:flow_impact).permit(:project_id, :demand_id, :start_date, :end_date, :impact_description, :impact_type)
  end

  def assign_project
    @project = Project.find(params[:project_id])
  end
end
