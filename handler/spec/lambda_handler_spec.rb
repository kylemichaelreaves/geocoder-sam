# frozen_string_literal: true

require_relative '../app'

WHITE_HOUSE_STREET = '1600 Pennsylvania Ave NW'
HACKENSACK_ADDRESS = '208 Anderson St, Hackensack, New Jersey, 07601'

RSpec.describe 'lambda_handler' do
  let(:logger) { instance_double(Logger) }
  let(:context) { {} }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
  end

  let(:geocoder_result) do
    double('Geocoder::Result::Base', data: {
             'address' => WHITE_HOUSE_STREET,
             'city' => 'Washington',
             'state' => 'DC',
             'postal_code' => '20500'
           })
  end

  context 'when given a valid address as individual query params' do
    let(:event) do
      {
        'queryStringParameters' => {
          'streetAddress' => WHITE_HOUSE_STREET,
          'municipality' => 'Washington',
          'state' => 'DC',
          'zipcode' => '20500'
        }
      }
    end

    it 'returns a successful response' do
      allow(Geocoder).to receive(:search).and_return([geocoder_result])

      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(200)
      expect(response[:headers]).to eq({ 'Content-Type' => 'application/json' })
      expect(response[:body]).to include(WHITE_HOUSE_STREET)
    end

    it 'joins the params into a single address string, dropping blanks' do
      expect(Geocoder).to receive(:search)
        .with("#{WHITE_HOUSE_STREET}, Washington, DC, 20500")
        .and_return([geocoder_result])

      lambda_handler(event: event, context: context, logger: logger)
    end
  end

  context 'when given a valid address as a JSON `address` param' do
    let(:event) do
      {
        'queryStringParameters' => {
          'address' => JSON.generate({
                                       'streetAddress' => '208 Anderson St',
                                       'aptNum' => '',
                                       'city' => 'Hackensack',
                                       'state' => 'New Jersey',
                                       'zipCode' => '07601'
                                     })
        }
      }
    end

    it 'parses the JSON blob and returns a successful response' do
      expect(Geocoder).to receive(:search)
        .with(HACKENSACK_ADDRESS)
        .and_return([geocoder_result])

      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(200)
    end
  end

  context 'when given a valid address as a POST JSON body' do
    let(:event) do
      {
        'httpMethod' => 'POST',
        'body' => JSON.generate({
                                  'streetAddress' => '208 Anderson St',
                                  'city' => 'Hackensack',
                                  'state' => 'New Jersey',
                                  'zipCode' => '07601'
                                })
      }
    end

    it 'parses the body and returns a successful response' do
      expect(Geocoder).to receive(:search)
        .with(HACKENSACK_ADDRESS)
        .and_return([geocoder_result])

      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(200)
    end

    it 'decodes a base64-encoded body' do
      encoded = [event['body']].pack('m0')
      base64_event = { 'httpMethod' => 'POST', 'body' => encoded, 'isBase64Encoded' => true }
      expect(Geocoder).to receive(:search)
        .with(HACKENSACK_ADDRESS)
        .and_return([geocoder_result])

      response = lambda_handler(event: base64_event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(200)
    end
  end

  context 'when the request contains malformed JSON' do
    it 'returns a 400 for a malformed `address` query param' do
      event = { 'queryStringParameters' => { 'address' => '{not valid json' } }
      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(400)
      expect(response[:body]).to include('Invalid JSON')
    end

    it 'returns a 400 for a malformed POST body' do
      event = { 'httpMethod' => 'POST', 'body' => '{not valid json' }
      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(400)
      expect(response[:body]).to include('Invalid JSON')
    end
  end

  context 'when no address can be resolved' do
    it 'returns a 400 when queryStringParameters is nil and there is no body' do
      response = lambda_handler(event: { 'queryStringParameters' => nil }, context: context, logger: logger)

      expect(response[:statusCode]).to eq(400)
      expect(response[:body]).to include('No address provided')
    end

    it 'returns a 400 when the params resolve to a blank address' do
      event = { 'queryStringParameters' => { 'streetAddress' => '', 'state' => '' } }
      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(400)
      expect(response[:body]).to include('No address provided')
    end
  end

  context 'when no results are found' do
    let(:event) { { 'queryStringParameters' => { 'streetAddress' => '1234 Invalid St', 'state' => 'CA' } } }

    it 'returns a not found error response' do
      allow(Geocoder).to receive(:search).and_return([])

      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(404)
      expect(response[:body]).to include('No results found for')
    end
  end

  context 'when the geocoder raises an error' do
    let(:event) { { 'queryStringParameters' => { 'streetAddress' => WHITE_HOUSE_STREET } } }

    it 'returns a 500 error response' do
      allow(Geocoder).to receive(:search).and_raise(StandardError.new('upstream timeout'))

      response = lambda_handler(event: event, context: context, logger: logger)

      expect(response[:statusCode]).to eq(500)
      expect(response[:body]).to include('Geocoder search failed')
    end
  end
end
