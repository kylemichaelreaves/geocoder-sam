require_relative '../app'

RSpec.describe 'lambda_handler' do
  let(:logger) { class_double(Logger) }
  let(:logger_instance) { instance_double(Logger) }
  let(:context) { {} }

  before do
    allow(logger).to receive(:new).and_return(logger_instance)
    allow(logger_instance).to receive(:info)
    allow(logger_instance).to receive(:warn)
    allow(logger_instance).to receive(:error)
  end

  context 'when given a valid address' do
    let(:event) do
      {
        'queryStringParameters' => {
          'streetAddress' => '1600 Pennsylvania Ave NW',
          'municipality' => 'Washington',
          'state' => 'DC',
          'zipcode' => '20500'
        }
      }
    end

    let(:geocoder_result) do
      double('Geocoder::Result::Base', data: {
        'address' => '1600 Pennsylvania Ave NW',
        'city' => 'Washington',
        'state' => 'DC',
        'postal_code' => '20500'
      })
    end

    it 'returns a successful response' do
      logger_instance = class_double(Logger)
      allow(logger).to receive(:new).and_return(logger_instance)
      allow(Geocoder).to receive(:search).and_return([geocoder_result])

      response = lambda_handler(event: event, context: context, logger: logger_instance)

      expect(response[:statusCode]).to eq(200)
      expect(response[:headers]).to eq({ 'Content-Type' => 'application/json' })
      expect(response[:body]).to include('1600 Pennsylvania Ave NW')
    end
  end

  context 'when given an invalid address' do
    let(:event) do
      {
        'queryStringParameters' => {
          'streetAddress' => '1234 Invalid St',
          'municipality' => 'Nowhere',
          'state' => 'CA',
          'zipcode' => '99999'
        }
      }
    end

    it 'returns a not found error response' do
      logger_instance = class_double(Logger)
      allow(logger).to receive(:new).and_return(logger_instance)
      allow(Geocoder).to receive(:search).and_return([])

      response = lambda_handler(event: event, context: context)

      expect(response[:statusCode]).to eq(404)
      expect(response[:headers]).to eq({ 'Content-Type' => 'application/json' })
      expect(response[:body]).to include('No results found for')
    end
  end
end