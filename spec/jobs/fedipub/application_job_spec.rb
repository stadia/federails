require 'rails_helper'

RSpec.describe Federails::ApplicationJob do
  it 'adds to configured queue' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue(:default)
  end

  it 'supports different queue names' do
    Federails.configuration.job_queue = :fedipub
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue(:fedipub)
    Federails.configuration.job_queue = :default
  end
end
