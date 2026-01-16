require 'json'
require 'optparse'

##
# TokenTopUpProcessor processes user and company data to generate token top-up reports
#
# This script reads JSON files containing user and company information, identifies
# active users eligible for token top-ups, and generates a formatted output report.
#
# Usage:
#   ruby challenge.rb [options]
#
# Options:
#   -u, --users PATH      Path to users JSON file (default: users.json)
#   -c, --companies PATH  Path to companies JSON file (default: companies.json)
#   -o, --output PATH     Path to output file (default: output.txt)
#   -h, --help            Show this help message
#
class TokenTopUpProcessor
  attr_reader :users_file, :companies_file, :output_file

  # Initialize the processor with file paths
  #
  # @param users_file [String] path to users JSON file
  # @param companies_file [String] path to companies JSON file
  # @param output_file [String] path to output text file
  def initialize(users_file: 'users.json', companies_file: 'companies.json', output_file: 'output.txt')
    @users_file = users_file
    @companies_file = companies_file
    @output_file = output_file
  end

  # Main processing method
  #
  # @return [Boolean] true if successful, false otherwise
  def process
    users = load_json_file(users_file, 'users')
    companies = load_json_file(companies_file, 'companies')

    return false if users.nil? || companies.nil?

    company_map = build_company_map(companies)
    eligible_users = filter_eligible_users(users, company_map)
    grouped_users = group_users_by_company(eligible_users)
    
    write_output(grouped_users, company_map)
    
    puts "Processing complete! Output written to #{output_file}"
    true
  rescue StandardError => e
    log_error("Unexpected error during processing: #{e.message}")
    false
  end

  private

  # Load and parse JSON file with error handling
  #
  # @param file_path [String] path to JSON file
  # @param file_type [String] descriptive name for error messages
  # @return [Array, nil] parsed JSON array or nil on error
  def load_json_file(file_path, file_type)
    unless File.exist?(file_path)
      log_error("#{file_type.capitalize} file not found: #{file_path}")
      return nil
    end

    content = File.read(file_path)
    JSON.parse(content)
  rescue JSON::ParserError => e
    log_error("Invalid JSON in #{file_type} file: #{e.message}")
    nil
  rescue StandardError => e
    log_error("Error reading #{file_type} file: #{e.message}")
    nil
  end

  # Build a hash map of companies keyed by ID
  #
  # @param companies [Array<Hash>] array of company hashes
  # @return [Hash] company ID to company hash mapping
  def build_company_map(companies)
    companies.each_with_object({}) do |company, map|
      next unless valid_company?(company)
      map[company['id']] = company
    end
  end

  # Validate company data structure
  #
  # @param company [Hash] company data
  # @return [Boolean] true if valid
  def valid_company?(company)
    return false unless company.is_a?(Hash)
    return false unless company['id'].is_a?(Integer)
    return false unless company['name'].is_a?(String)
    return false unless company['top_up'].is_a?(Integer)
    
    true
  rescue StandardError
    false
  end

  # Filter users to only include active users belonging to valid companies
  #
  # @param users [Array<Hash>] array of user hashes
  # @param company_map [Hash] company ID to company mapping
  # @return [Array<Hash>] filtered users with enhanced data
  def filter_eligible_users(users, company_map)
    users.select do |user|
      valid_user?(user) &&
        user['active_status'] == true &&
        company_map.key?(user['company_id'])
    end.map do |user|
      enhance_user_data(user, company_map)
    end
  end

  # Validate user data structure
  #
  # @param user [Hash] user data
  # @return [Boolean] true if valid
  def valid_user?(user)
    return false unless user.is_a?(Hash)
    return false unless user['company_id'].is_a?(Integer)
    return false unless user['last_name'].is_a?(String)
    return false unless [true, false].include?(user['active_status'])
    return false unless [true, false].include?(user['email_status'])
    return false unless user['tokens'].is_a?(Integer)
    
    true
  rescue StandardError
    false
  end

  # Enhance user data with company information and calculations
  #
  # @param user [Hash] user data
  # @param company_map [Hash] company mapping
  # @return [Hash] enhanced user data
  def enhance_user_data(user, company_map)
    company = company_map[user['company_id']]
    top_up = company['top_up']
    
    user.merge(
      'company_name' => company['name'],
      'top_up_amount' => top_up,
      'new_token_balance' => user['tokens'] + top_up,
      'should_send_email' => user['email_status'] == true && company['email_status'] == true
    )
  end

  # Group users by company ID and sort
  #
  # @param users [Array<Hash>] filtered users
  # @return [Hash] company ID to sorted users array mapping
  def group_users_by_company(users)
    grouped = users.group_by { |user| user['company_id'] }
    
    # Sort companies by ID and users by last name
    grouped.sort.to_h.transform_values do |company_users|
      company_users.sort_by { |user| user['last_name'].downcase }
    end
  end

  # Write formatted output to file
  #
  # @param grouped_users [Hash] grouped and sorted users
  # @param company_map [Hash] company mapping
  def write_output(grouped_users, company_map)
    File.open(output_file, 'w') do |file|
      grouped_users.each do |company_id, users|
        company = company_map[company_id]
        write_company_section(file, company, users)
      end
    end
  rescue StandardError => e
    log_error("Error writing output file: #{e.message}")
    raise
  end

  # Write a company section to the output file
  #
  # @param file [File] output file handle
  # @param company [Hash] company data
  # @param users [Array<Hash>] sorted users for this company
  def write_company_section(file, company, users)
    file.puts "\tCompany Id: #{company['id']}"
    file.puts "\tCompany Name: #{company['name']}"
    file.puts "\tUsers Emailed:"
    
    users.each do |user|
      write_user_line(file, user)
    end
    
    file.puts "\t\tTotal amount of top ups for #{company['name']}: #{calculate_total_topup(users)}"
    file.puts # blank line between companies
  end

  # Write a single user line to the output file
  #
  # @param file [File] output file handle
  # @param user [Hash] user data
  def write_user_line(file, user)
    full_name = "#{user['last_name']}, #{user['first_name']}"
    email_status = user['should_send_email']
    previous_balance = user['tokens']
    new_balance = user['new_token_balance']
    
    file.puts "\t\t#{full_name}, #{user['email']}"
    file.puts "\t\t  Previous Token Balance, #{previous_balance}"
    file.puts "\t\t  New Token Balance #{new_balance}"
    file.puts "\t\t  #{email_status ? 'Email sent' : 'Email not sent'}"
  end

  # Calculate total top-up amount for a group of users
  #
  # @param users [Array<Hash>] users to sum
  # @return [Integer] total top-up amount
  def calculate_total_topup(users)
    users.sum { |user| user['top_up_amount'] }
  end

  # Log error message to STDERR
  #
  # @param message [String] error message
  def log_error(message)
    warn "ERROR: #{message}"
  end
end

# Parse command line options
def parse_options
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: challenge.rb [options]"
    
    opts.on('-u', '--users PATH', 'Path to users JSON file (default: users.json)') do |path|
      options[:users_file] = path
    end
    
    opts.on('-c', '--companies PATH', 'Path to companies JSON file (default: companies.json)') do |path|
      options[:companies_file] = path
    end
    
    opts.on('-o', '--output PATH', 'Path to output file (default: output.txt)') do |path|
      options[:output_file] = path
    end
    
    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      exit
    end
  end.parse!
  
  options
end

# Main execution block
if __FILE__ == $PROGRAM_NAME
  options = parse_options
  processor = TokenTopUpProcessor.new(**options)
  exit_code = processor.process ? 0 : 1
  exit exit_code
end