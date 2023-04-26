require 'json'
require 'logger'
require 'geocoder'
require 'uri'

def lambda_handler(event:, context:,  logger: Logger.new($stdout))
  logger = Logger.new($stdout)
  logger.info('## ENVIRONMENT VARIABLES')
  logger.info(ENV.to_a)
  logger.info('## EVENT')
  logger.info(event)
  logger.info('## CONTEXT')
  logger.info(context)

  if event['queryStringParameters'] && !event['queryStringParameters'].empty?
    address_keys = %w[streetAddress unitOrAptNum municipality state zipcode]

    address_hash = address_keys.each_with_object({}) do |key, hash|
      hash[key.downcase] = event['queryStringParameters'][key] if event['queryStringParameters'][key]
    end

    logger.info("address_hash: #{address_hash}")

    joined_address = address_hash.values.reject(&:empty?).join(", ")
    logger.info("joined_address: #{joined_address}")

    return build_error_response(logger, 'The address object was empty', 400) if joined_address.empty?

    begin
      results = Geocoder.search(joined_address)
      if results.empty?
        logger.warn("No results found for #{joined_address}")
        build_error_response(logger, "No results found for #{joined_address}", 404)
      else
        logger.info("Found #{results.count} results for #{joined_address}")
        logger.info("Results: #{results.map(&:data)}")
        {
          statusCode: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ message: results.map(&:data) })
        }
      end
    rescue => e
      error_message = "Geocoder search failed: #{e.message}"
      logger.error(error_message)
      build_error_response(logger, error_message, 500)
    end
  end
end

def build_error_response(logger, error_message, status_code)
  logger.error(error_message)
  {
    statusCode: status_code,
    headers: { 'Content-Type' => 'application/json' },
    body: JSON.generate({ message: error_message })
  }
end
