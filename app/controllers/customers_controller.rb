# frozen_string_literal: true

class CustomersController < AuthenticatedController
  before_action :user_gold_check
  before_action :assign_company
  before_action :assign_customer, only: %i[edit update show destroy add_user_to_customer]

  def index
    @customers = @company.customers.order(:name)

    @start_date = @customers.map(&:projects).flatten.map(&:start_date).min
    @end_date = @customers.map(&:projects).flatten.map(&:end_date).max
  end

  def show
    @customer_dashboard_data = CustomerDashboardData.new(@customer)
    @user_invite = UserInvite.new(invite_object_id: @customer.id, invite_type: :customer)
    @contracts = @customer.contracts.order(end_date: :desc)
    @contract = Contract.new(customer: @customer)
  end

  def new
    @customer = Customer.new(company: @company)
  end

  def create
    @customer = Customer.new(customer_params.merge(company: @company))
    return redirect_to company_customers_path(@company) if @customer.save

    render :new
  end

  def edit; end

  def update
    @customer.update(customer_params.merge(company: @company))
    return redirect_to company_customers_path(@company) if @customer.save

    render :edit
  end

  def destroy
    return redirect_to company_customers_path(@company) if @customer.destroy

    redirect_to(company_customers_path(@company), flash: { error: @customer.errors.full_messages.join(',') })
  end

  def add_user_to_customer
    invite_email = user_invite_params[:invite_email]

    if invite_email.present?
      flash[:notice] = UserInviteService.instance.invite_customer(@company, @customer.id, invite_email, new_devise_customer_registration_url(user_email: invite_email))
    else
      flash[:error] = I18n.t('user_invites.create.error')
    end

    redirect_to company_customer_path(@company, @customer)
  end

  private

  def assign_customer
    @customer = @company.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name)
  end

  def user_invite_params
    params.require(:user_invite).permit(:invite_email, :invite_object_id, :invite_type)
  end
end
