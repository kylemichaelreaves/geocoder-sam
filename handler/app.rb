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
  logger.info('## CONTEXT')
  logger.info(context)
  # check for the address object on the queryStringParameters
  # if the address object is present, use it to build the address
  if event['queryStringParameters'] && !event['queryStringParameters'].empty?
    address_hash = {}
    # event['queryStringParameters'].each do |key, value|
    #   address_hash[key.downcase] = value
    # end
    address_keys = %w[streetAddress unitOrAptNum municipality state zipcode]

    # iterate over the address_keys list and construct the address_hash accordingly
    address_keys.each do |key|
      if event['queryStringParameters'][key]
        address_hash[key.downcase] = event['queryStringParameters'][key]
      end
    end
    logger.info("address_hash: #{address_hash}")

    # build the joined address
    joined_address = address_hash.map do |key, value|
      key == 'aptorunitnum' ? "#{value} " : "#{value},"
    end.compact.join("")
    logger.info("joined_address: #{joined_address}")

    # if the joined address is empty, return an error
    if joined_address.empty?
      error_message = 'The address object was empty'
      logger.error(error_message)
      return {
        statusCode: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: JSON.generate({ message: error_message })
      }
    end

    # search for the address using the Geocoder gem
    begin
      results = Geocoder.search(joined_address)
      if results.empty?
        logger.warn("No results found for #{joined_address}")
        return {
          statusCode: 404,
          headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ message: "No results found for #{joined_address}" })
        }
      else
        logger.info("Found #{results.count} results for #{joined_address}")
        { statusCode: 200,
          headers: {
            'Content-Type' => 'application/json'
          },
          body: JSON.generate({ message: results.map { |res| res.data } })
        }
      end
    rescue => e
      error_message = "Geocoder search failed: #{e.message}"
      logger.error(error_message)
      {
        statusCode: 500,
        headers: { 'Content-Type' => 'application/json' },
        body: JSON.generate({ message: error_message })
      }
    end
  end
end
