require 'rails_helper'

module Federails
  RSpec.describe DeadLetter, type: :model do
    let(:actor) { FactoryBot.create :local_actor }
    let(:activity) { Activity.create!(actor: actor, entity: actor, action: 'Create') }
    let(:inbox_url) { 'https://remote.example.com/inbox' }

    describe 'validations' do
      it 'requires target_inbox' do
        dl = described_class.new(activity: activity, target_inbox: nil)
        expect(dl).not_to be_valid
        expect(dl.errors[:target_inbox]).to include("can't be blank")
      end

      it 'enforces uniqueness of target_inbox scoped to activity' do
        described_class.create!(activity: activity, target_inbox: inbox_url)
        duplicate = described_class.new(activity: activity, target_inbox: inbox_url)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:target_inbox]).to include('has already been taken')
      end

      it 'allows same inbox for different activities' do
        activity2 = Activity.create!(actor: actor, entity: actor, action: 'Update')
        described_class.create!(activity: activity, target_inbox: inbox_url)
        dl = described_class.new(activity: activity2, target_inbox: inbox_url)
        expect(dl).to be_valid
      end
    end

    describe '.record_failure' do
      it 'creates a new dead letter on first failure' do
        dl = described_class.record_failure(activity: activity, target_inbox: inbox_url, error: 'Gone')
        expect(dl).to be_persisted
        expect(dl.attempts).to eq 1
        expect(dl.last_error).to eq 'Gone'
        expect(dl.last_attempted_at).to be_within(1.second).of(Time.current)
      end

      it 'increments attempts on subsequent failures' do
        described_class.record_failure(activity: activity, target_inbox: inbox_url, error: 'Gone')
        dl = described_class.record_failure(activity: activity, target_inbox: inbox_url, error: 'Not Found')
        expect(dl.attempts).to eq 2
        expect(dl.last_error).to eq 'Not Found'
      end
    end
  end
end
