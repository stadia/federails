RSpec.shared_examples 'denies access when unauthenticated' do
  context 'when unauthenticated' do
    it 'denies access' do
      expect(described_class).not_to permit(nil, policy_subject)
    end
  end
end

RSpec.shared_examples 'grants access when unauthenticated' do
  context 'when unauthenticated' do
    it 'grants access' do
      expect(described_class).to permit(nil, policy_subject)
    end
  end
end

RSpec.shared_examples 'grants access when authenticated' do
  context 'when authenticated' do
    it 'grants access' do
      expect(described_class).to permit(signed_in_user, policy_subject)
    end
  end
end

RSpec.shared_examples 'denies access when user is not federable' do
  context 'when authenticated user is not federable' do
    it 'denies access' do
      expect(described_class).not_to permit(Class.new, policy_subject)
    end
  end
end

RSpec.shared_examples 'grants access when user is federable' do
  context 'when authenticated user is federable' do
    it 'grants access' do
      expect(described_class).to permit(signed_in_user, policy_subject)
    end
  end
end

RSpec.shared_examples 'an action for authenticated users only' do
  it_behaves_like 'denies access when unauthenticated'
  it_behaves_like 'grants access when authenticated'
end

RSpec.shared_examples 'an action for everyone' do
  it_behaves_like 'grants access when unauthenticated'
  it_behaves_like 'grants access when authenticated'
end

RSpec.shared_examples 'an action for federable instances only' do
  it_behaves_like 'denies access when unauthenticated'
  it_behaves_like 'denies access when user is not federable'
  it_behaves_like 'grants access when user is federable'
end
