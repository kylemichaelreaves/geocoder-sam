require 'json'
require 'logger'
require 'geocoder'

# Nominatim (the default lookup) requires an identifying User-Agent and rejects
# requests without one. Keep the timeout comfortably under the Lambda timeout.
Geocoder.configure(
  timeout: 5,
  http_headers: { 'User-Agent' => 'geocoder-sam (https://github.com/babbel/geocoder-sam)' }
)

# Keys accepted when the caller sends individual query-string parameters (the
# canonical RESTful GET contract), in the order they should be joined.
INDIVIDUAL_ADDRESS_KEYS = %w[streetAddress unitOrAptNum municipality state zipcode].freeze

# Keys accepted from a structured JSON payload — either a POST request body (the
# RESTful way to send structured input) or the deprecated `address` query param
# that carries JSON-in-a-query-string. Ordered for joining.
JSON_ADDRESS_KEYS = %w[streetAddress aptNum city state zipCode].freeze

def lambda_handler(event:, context:, logger: Logger.new($stdout))
  logger.info('## EVENT')
  logger.info(event)

  begin
    joined_address = extract_address(event)
  rescue JSON::ParserError => e
    return build_error_response(logger, "Invalid JSON request: #{e.message}", 400)
  end

  logger.info("joined_address: #{joined_address}")
  return build_error_response(logger, 'No address provided', 400) if joined_address.empty?

  begin
    results = Geocoder.search(joined_address)
    if results.empty?
      build_error_response(logger, "No results found for #{joined_address}", 404)
    else
      logger.info("Found #{results.count} results for #{joined_address}")
      {
        statusCode: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: JSON.generate({ message: results.map(&:data) })
      }
    end
  rescue StandardError => e
    build_error_response(logger, "Geocoder search failed: #{e.message}", 500)
  end
end

# Resolves a single address string from whichever input shape the caller used:
#   1. POST JSON body                 (RESTful structured input)
#   2. `address` query param (JSON)   (deprecated compat shim)
#   3. individual query params        (canonical RESTful GET)
# Values are stripped, blanks dropped, and joined by ", ".
def extract_address(event)
  params = event['queryStringParameters'] || {}
  body = parse_body(event)

  source, keys =
    if body && !body.empty?
      [body, JSON_ADDRESS_KEYS]
    elsif params['address']
      [JSON.parse(params['address']), JSON_ADDRESS_KEYS]
    else
      [params, INDIVIDUAL_ADDRESS_KEYS]
    end

  keys.filter_map { |key| source[key]&.to_s&.strip }
      .reject(&:empty?)
      .join(', ')
end

# Parses a request body into a Hash, decoding base64 first when API Gateway flags
# the body as encoded. Returns nil when there is no body.
def parse_body(event)
  raw = event['body']
  return nil if raw.nil? || raw.empty?

  raw = raw.unpack1('m') if event['isBase64Encoded']
  JSON.parse(raw)
end

def build_error_response(logger, error_message, status_code)
  logger.error(error_message)
  {
    statusCode: status_code,
    headers: { 'Content-Type' => 'application/json' },
    body: JSON.generate({ message: error_message })
  }
end
