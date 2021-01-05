# frozen_string_literal: true

namespace :statistics do
  desc 'Data cache for projects'
  task consolidate_active_projects: :environment do
    Company.all.each do |company|
      company.projects.active.finishing_after(Time.zone.today).each { |project| Consolidations::ProjectConsolidationJob.perform_later(project) }
    end
  end

  desc 'Data cache for projects - all time'
  task consolidate_active_projects_all_time: :environment do
    Company.all.each do |company|
      company.projects.active.finishing_after(Time.zone.today.beginning_of_year).each do |project|
        cache_date_arrays = TimeService.instance.days_between_of(project.start_date, Time.zone.today)
        cache_date_arrays.each { |cache_date| Consolidations::ProjectConsolidationJob.perform_later(project, cache_date) }
      end
    end
  end

  desc 'Consolidations for contracts'
  task consolidate_contracts: :environment do
    Company.all.each do |company|
      company.customers.each do |customer|
        customer.contracts.active(Time.zone.today).each do |contract|
          Consolidations::ContractConsolidationJob.perform_later(contract)
        end
      end
    end
  end

  desc 'Consolidations for customers'
  task consolidate_customers: :environment do
    Company.all.each do |company|
      company.customers.each do |customer|
        Consolidations::CustomerConsolidationJob.perform_later(customer)
      end
    end
  end

  desc 'Consolidations for customers - all time'
  task consolidate_customers_all_time: :environment do
    Company.all.each do |company|
      company.customers.each do |customer|
        start_date = customer.start_date
        end_date = customer.end_date

        cache_date_arrays = TimeService.instance.days_between_of(start_date, end_date)
        cache_date_arrays.each { |cache_date| Consolidations::CustomerConsolidationJob.perform_later(customer, cache_date) }
      end
    end
  end

  desc 'Consolidations for replenishing'
  task consolidate_replenishing: :environment do
    Consolidations::ReplenishingConsolidationJob.perform_later
  end
end
