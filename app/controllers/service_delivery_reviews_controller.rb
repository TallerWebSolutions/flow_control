# frozen_string_literal: true

class ServiceDeliveryReviewsController < AuthenticatedController
  before_action :assign_company
  before_action :assign_product

  before_action :assign_service_delivery_review, only: %i[show destroy edit update]

  def new
    @service_delivery_review = ServiceDeliveryReview.new(product: @product)
    service_delivery_reviews

    respond_to { |format| format.js { render 'service_delivery_reviews/new.js.erb' } }
  end

  def create
    @service_delivery_review = ServiceDeliveryReview.create(service_delivery_review_params.merge(company: @company, product: @product).merge(time_computed_params).merge(percent_computed_params))

    ServiceDeliveryReviewService.instance.associate_demands_data(@product, @service_delivery_review) if @service_delivery_review.valid?

    service_delivery_reviews

    respond_to { |format| format.js { render 'service_delivery_reviews/create' } }
  end

  def show
    @demands_chart_adapter = Highchart::DemandsChartsAdapter.new(@service_delivery_review.demands, 12.weeks.ago, Time.zone.today, 'week')
  end

  def destroy
    @service_delivery_review.destroy
    respond_to { |format| format.js { render 'service_delivery_reviews/destroy' } }
  end

  def edit
    service_delivery_reviews
    render 'service_delivery_reviews/edit'
  end

  def update
    @service_delivery_review.update(service_delivery_review_params.merge(time_computed_params).merge(percent_computed_params))
    if @service_delivery_review.valid?
      ServiceDeliveryReviewService.instance.associate_demands_data(@product, @service_delivery_review)
      @service_delivery_reviews = @product.service_delivery_reviews.order(meeting_date: :desc)
    end

    render 'service_delivery_reviews/update'
  end

  private

  def service_delivery_reviews
    @service_delivery_reviews ||= @product.service_delivery_reviews.order(meeting_date: :desc)
  end

  def assign_service_delivery_review
    @service_delivery_review = @product.service_delivery_reviews.find(params[:id])
  end

  def service_delivery_review_params
    params.require(:service_delivery_review).permit(:meeting_date, :delayed_expedite_bottom_threshold, :delayed_expedite_top_threshold, :expedite_max_pull_time_sla, :lead_time_bottom_threshold, :lead_time_top_threshold, :quality_bottom_threshold, :quality_top_threshold)
  end

  def time_computed_params
    {
      expedite_max_pull_time_sla: service_delivery_review_params[:expedite_max_pull_time_sla].to_f * 1.hour,
      lead_time_bottom_threshold: service_delivery_review_params[:lead_time_bottom_threshold].to_f * 1.hour,
      lead_time_top_threshold: service_delivery_review_params[:lead_time_top_threshold].to_f * 1.hour
    }
  end

  def percent_computed_params
    {
      delayed_expedite_bottom_threshold: service_delivery_review_params[:delayed_expedite_bottom_threshold].to_f / 100.0,
      delayed_expedite_top_threshold: service_delivery_review_params[:delayed_expedite_top_threshold].to_f / 100.0,
      quality_bottom_threshold: service_delivery_review_params[:quality_bottom_threshold].to_f / 100.0,
      quality_top_threshold: service_delivery_review_params[:quality_top_threshold].to_f / 100.0
    }
  end

  def assign_product
    @product = Product.find(params[:product_id])
  end
end
