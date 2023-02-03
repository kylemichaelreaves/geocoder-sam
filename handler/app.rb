require 'json'
require 'logger'
require 'geocoder'
require 'uri'

def lambda_handler(event:, context:)
  logger = Logger.new($stdout)
  logger.info('## ENVIRONMENT VARIABLES')
  logger.info(ENV.to_a)
  logger.info('## EVENT')
  logger.info(event)
  # check for the address object on the queryStringParameters
  # if the address object is present, use it to build the address
  if event['queryStringParameters'] && event['queryStringParameters']['address']
    query_string = event['queryStringParameters']['address']
    if query_string.empty?
      logger.info('The query_string was empty.')
      return { statusCode: 400,
               headers: { 'Content-Type' => 'application/json' },
               body: JSON.generate({ message: 'The query_string was empty.' })
      }
    end
    logger.info("query_string: #{query_string}")
    address_hash = JSON.parse(query_string)
    logger.info(`address_hash: #{address_hash}`)
    # concat a string from the address_hash by iterating over it
    joined_address = address_hash.map do |key, value|
      key == 'aptNum' ? "#{value} " : "#{value},"
    end.compact
    # if an address cannot be built from the address for whatever reason, return an error
    if joined_address.all?(&:empty?)
      { statusCode: 400,
        headers: {
          'Content-Type' => 'application/json'
        },
        body: JSON.generate({ message: 'the joined_address was empty' })
      }
    end
    # join the address array into a string
    joined_address = joined_address.join("")
    results = Geocoder.search(joined_address)
    # if no results, return an error
    # otherwise, return the results
    if results.empty?
      { statusCode: 400,
        headers: {
          'Content-Type' => 'application/json'
        },
        body: JSON.generate({ message: "No results found for #{joined_address}" }) }
    else
      # log the results
      logger.info("results: #{results.to_json}")
      # iterate over the results, returning each result as a JSON object
      results.each { |result| logger.info(result.data.to_json) }
      { statusCode: 200,
        headers: {
          'Content-Type' => 'application/json'
        },
        body: JSON.generate({ message: results.each { |res| res.data.to_json } }) }
    end
  end
end

