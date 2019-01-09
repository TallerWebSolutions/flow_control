# frozen_string_literal: true

class ProductsController < AuthenticatedController
  before_action :user_gold_check

  before_action :assign_company
  before_action :assign_product, only: %i[show edit update destroy]

  def index
    @products = @company.products.order(:name)
  end

  def show
    @product_projects = @product.projects.order(end_date: :desc)
    @projects_summary = ProjectsSummaryData.new(@product.projects)
    return render :show if @product_projects.blank?

    @report_data = Highchart::OperationalChartsAdapter.new(@product_projects, 'all')
    @status_report_data = Highchart::StatusReportChartsAdapter.new(@product_projects, 'all')
    @montecarlo_durations = @status_report_data.deadline_vs_montecarlo_durations
  end

  def new
    @product = Product.new
  end

  def edit; end

  def update
    customer = Customer.find_by(id: product_params[:customer_id])
    @product.update(product_params.merge(customer: customer))
    return redirect_to company_products_path(@company) if @product.save

    render :edit
  end

  def create
    customer = Customer.find_by(id: product_params[:customer_id])
    @product = Product.new(product_params.merge(customer: customer))
    return redirect_to company_products_path(@company) if @product.save

    render :new
  end

  def products_for_customer
    render_products_for_customer('products/products.js.erb', params[:customer_id])
  end

  def destroy
    return redirect_to company_products_path(@company) if @product.destroy

    redirect_to(company_products_path(@company), flash: { error: @product.errors.full_messages.join(',') })
  end

  private

  def product_params
    params.require(:product).permit(:customer_id, :team_id, :name)
  end

  def assign_product
    @product = Product.find(params[:id])
  end
end
