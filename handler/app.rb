# require 'httparty'
require 'json'
require 'logger'
require 'geocoder'

def lambda_handler(event:, context:)

  logger = Logger.new($stdout)
  logger.info('## ENVIRONMENT VARIABLES')
  logger.info(ENV.to_a)
  logger.info('## EVENT')
  logger.info(event)
  event.to_a

  # if the queryStringParameters are not present, return an error
  if event['queryStringParameters'].nil? || event['queryStringParameters'].empty?
    { statusCode: 400, body: JSON.generate({ message: 'Missing queryStringParameters' }) }
  end

  street_address = event['queryStringParameters']['street_address']
  apt_num = event['queryStringParameters'].fetch('apt_num', '')
  city = event['queryStringParameters']['city']
  state = event['queryStringParameters']['state']
  zipcode = event['queryStringParameters'].fetch('zipcode', '')

  address = "#{street_address} #{apt_num}, #{city}, #{state} #{zipcode}"

  # if all the elements in the array are empty or nil, return an error
  if address.all?(&:empty?)
    { statusCode: 400, body: JSON.generate({ message: 'An address could not be formed from the queryStringParameters' }) }
    break
  else

    results = Geocoder.search(address)

    results.headers = {
      'Access-Control-Allow-Origin' => '*',
      'Access-Control-Allow-Headers' => 'Content-Type',
      'Access-Control-Allow-Methods' => 'OPTIONS,POST,GET'
    }

    if results.empty?
      { statusCode: 200, body: JSON.generate({ message: "No results found for #{address}" }) }
    else
      { statusCode: 200, body: JSON.generate({ message: results.to_json }) }
    end

  end

end
