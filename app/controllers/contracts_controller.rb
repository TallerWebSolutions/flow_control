# frozen_string_literal: true

class ContractsController < AuthenticatedController
  before_action :assign_company
  before_action :assign_customer
  before_action :assign_contract, only: %i[edit update destroy]

  def new
    @contract = Contract.new(customer: @customer)
    assign_products_in_customer
  end

  def create
    @contract = Contract.new(contract_params.merge(customer: @customer))
    if @contract.save
      flash[:notice] = I18n.t('contracts.create.success')
      redirect_to company_customer_path(@company, @customer)
    else
      assign_products_in_customer
      flash[:error] = I18n.t('contracts.save.error')
      render :new
    end
  end

  def edit
    assign_products_in_customer
  end

  def update
    @contract.update(contract_params.merge(customer: @customer))

    if @contract.save
      flash[:notice] = I18n.t('contracts.update.success')
      redirect_to company_customer_path(@company, @customer)
    else
      assign_products_in_customer
      flash[:error] = I18n.t('contracts.save.error')
      render :edit
    end
  end

  def destroy
    @contract.destroy
    redirect_to company_customer_path(@company, @customer)
  end

  private

  def assign_products_in_customer
    @products_in_customer = @customer.products.order(:name)
  end

  def assign_contract
    @contract = @customer.contracts.find(params[:id])
  end

  def assign_customer
    @customer = @company.customers.find(params[:customer_id])
  end

  def contract_params
    params.require(:contract).permit(:start_date, :end_date, :total_hours, :total_value, :hours_per_demand, :renewal_period, :automatic_renewal, :product_id, :contract_id)
  end
end
