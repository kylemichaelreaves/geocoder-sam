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

  # check for the address object on the queryStringParameters
  # if the address object is present, use it to build the address
  if event['queryStringParameters'] && event['queryStringParameters']['address']
    #   build the address from the address object by iterating over it
    joined_address = event['queryStringParameters']['address'].map do |key, value|
      key == 'aptNum' ? "#{value} " : "#{value}, "
    end.compact

    results = Geocoder.search(joined_address)
    # if no results, return an error
    # otherwise, return the results
    if results.empty?
      { statusCode: 400,
        headers: {
          'Content-Type' => 'application/json'
        },
        body: JSON.generate({ message: "No results found for #{address}" }) }
    else
      { statusCode: 200,
        headers: {
          'Content-Type' => 'application/json'
        },
        body: JSON.generate({ message: results.to_json }) }
    end

  end
end

