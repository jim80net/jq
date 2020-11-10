describe Yq do
  subject { described_class }

  let(:hash) do
    { 'foo' => { 'bar' => { "'" => 'value' } } }
  end

  let(:yaml) { <<~EOF }
    foo:
      bar:
        "'": value
  EOF

  # support equivalent YAML syntaxes (depends on ruby version)
  let(:yaml_regexp) { <<~EOF }
    foo:
      bar:
        ("'"|''''|! ''''): value
  EOF

  let(:json) { <<~EOF.chomp }
    {"foo":{"bar":{"'":"value"}}}
  EOF

  let(:jq_query) { %q({"\\t": .foo.bar["'"]}) }

  let(:jq_response) { <<~EOF }
    {
      "\\t": "value"
    }
  EOF

  let(:jq_non_json_response) { <<~EOF }
    "foo"
    "bar"
    "baz"
  EOF

  let(:yaml_from_non_json_response) { <<~EOF }
    ---
    - foo
    - bar
    - baz
  EOF

  let(:jq_non_json_response_2) { <<~EOF }
    {
      "foo": "bar",
      "baz": {
        "blah": 10240,
        "asdf": "qwer"
      },
      "bing": "bo.ng"
    }
    {
      "foo": "far",
      "bing": "ba.ng"
    }
    [1,2,3]
    [4,5,6]
    "asdf"
    "qwer"
  EOF

  let(:yaml_from_non_json_response_2) { <<~EOF }
    ---
    - foo: bar
      baz:
        blah: 10240
        asdf: qwer
      bing: bo.ng
    - foo: far
      bing: ba.ng
    - - 1
      - 2
      - 3
    - - 4
      - 5
      - 6
    - asdf
    - qwer
  EOF

  describe '.search' do
    subject { described_class.search(jq_query, json) }

    it { is_expected.to match(jq_response) }

    it 'passes it through to jq' do
      allow(Yq).to receive(:which).with('jq').and_return('/bin/jq')
      expect(Open3).to receive(:popen2).with('/bin/jq', jq_query).and_return(jq_response)
      subject
    end

    context 'unclean exit' do
      subject { described_class.search '.foobar', json }

      it 'stops processing when jq exits uncleanly' do
        # not mocking at this level, see implementation
      end
    end
  end

  describe '.yaml_to_hash' do
    subject { described_class.yaml_to_hash(yaml) }
    it { is_expected.to match(hash) }
  end

  describe '.hash_to_yaml' do
    subject { described_class.hash_to_yaml(hash) }
    it { is_expected.to match(yaml_regexp) }
  end

  describe '.yaml_to_json' do
    subject { described_class.yaml_to_json(yaml) }
    it { is_expected.to match(json) }
  end

  describe '.json_to_yaml' do
    subject { described_class.json_to_yaml(json) }
    it { is_expected.to match(yaml_regexp) }

    context 'non-json response' do
      subject { described_class.json_to_yaml(jq_non_json_response) }
      it { is_expected.to match(yaml_from_non_json_response) }
    end

    context 'non-json response 2' do
      subject { described_class.json_to_yaml(jq_non_json_response_2) }
      it { is_expected.to match(yaml_from_non_json_response_2) }
    end
  end

  describe '.search_yaml' do
    subject { described_class.search_yaml('.foo.bar', yaml) }

    it { is_expected.to match(/("'"|''''|! ''''): value/) }
  end

  describe '.which' do
    subject { described_class.which('jq') }

    before(:each) do
      allow(ENV).to receive(:[]).with('PATH').and_return('/bin:/other/bin')
      allow(File).to receive(:executable?).with('/bin/jq').and_return(false)
      allow(File).to receive(:directory?).with('/bin/jq').and_return(false)
      allow(File).to receive(:directory?).with('/other/bin/jq').and_return(false)
    end

    context 'but it does not exist' do
      before(:each) do
        allow(File).to receive(:executable?).with('/other/bin/jq').and_return(false)
      end
      it { is_expected.to be_falsey }
    end

    context 'and it does exist' do
      before(:each) do
        allow(File).to receive(:executable?).with('/other/bin/jq').and_return(true)
      end
      it { is_expected.to eq('/other/bin/jq') }
    end
  end
end
