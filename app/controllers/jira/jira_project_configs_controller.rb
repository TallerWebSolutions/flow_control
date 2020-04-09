# frozen_string_literal: true

module Jira
  class JiraProjectConfigsController < AuthenticatedController
    before_action :assign_company
    before_action :assign_project
    before_action :assign_jira_project_config, only: %i[destroy synchronize_jira]

    def new
      @jira_project_config = JiraProjectConfig.new
      @jira_product_configs = @project.products.map(&:jira_product_configs).flatten
      respond_to { |format| format.js { render 'jira/jira_project_configs/new' } }
    end

    def create
      @jira_project_config = JiraProjectConfig.new(jira_project_config_params.merge(project: @project))
      flash[:error] = I18n.t('jira_project_config.validations.fix_version_name_uniqueness.message') unless @jira_project_config.save

      render 'jira/jira_project_configs/create'
    end

    def destroy
      @jira_project_config.destroy
      render 'jira/jira_project_configs/destroy'
    end

    def synchronize_jira
      jira_account = @company.jira_accounts.first

      project_url = company_project_url(@company, @project)
      Jira::ProcessJiraProjectJob.perform_later(jira_account, @jira_project_config, current_user.email, current_user.full_name, project_url)
      flash[:notice] = I18n.t('general.enqueued')

      respond_to { |format| format.js { render 'jira/jira_project_configs/synchronize_jira' } }
    end

    private

    def assign_jira_project_config
      @jira_project_config = JiraProjectConfig.find(params[:id])
    end

    def jira_project_config_params
      params.require(:jira_jira_project_config).permit(:jira_product_config_id, :fix_version_name)
    end

    def assign_project
      @project = Project.find(params[:project_id])
    end
  end
end
