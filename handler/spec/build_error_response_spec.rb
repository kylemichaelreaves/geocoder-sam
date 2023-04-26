require 'json'
require_relative '../app'

RSpec.describe 'build_error_response' do
  let(:logger) { instance_double(Logger) }
  let(:error_message) { 'Test error message' }

  before do
    allow(logger).to receive(:error)
  end

  context 'when given a valid input' do
    let(:status_code) { 400 }

    it 'returns an error response with the correct status code and message' do
      response = build_error_response(logger, error_message, status_code)

      expect(response[:statusCode]).to eq(status_code)
      expect(response[:headers]).to eq({ 'Content-Type' => 'application/json' })
      expect(response[:body]).to eq(JSON.generate({ message: error_message }))
    end

    it 'logs the error message' do
      build_error_response(logger, error_message, status_code)
      expect(logger).to have_received(:error).with(error_message)
    end
  end

  context 'when given different status codes' do
    it 'returns an error response with the correct status code for 404' do
      status_code = 404
      response = build_error_response(logger, error_message, status_code)

      expect(response[:statusCode]).to eq(status_code)
      expect(response[:headers]).to eq({ 'Content-Type' => 'application/json' })
      expect(response[:body]).to eq(JSON.generate({ message: error_message }))
    end

    it 'returns an error response with the correct status code for 500' do
      status_code = 500
      response = build_error_response(logger, error_message, status_code)

      expect(response[:statusCode]).to eq(status_code)
      expect(response[:headers]).to eq({ 'Content-Type' => 'application/json' })
      expect(response[:body]).to eq(JSON.generate({ message: error_message }))
    end
  end
end
