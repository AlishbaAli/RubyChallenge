#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'sinatra/cross_origin'
require 'json'
require_relative 'challenge'

# Configuration
configure do
  enable :cross_origin
  set :allow_origin, '*'  # Allow all origins for development
  set :allow_methods, 'GET,HEAD,POST,OPTIONS'
  set :allow_headers, 'content-type,if-modified-since'
  set :expose_headers, 'location,link'
  set :bind, '0.0.0.0'
  set :port, 4567
end

# Handle preflight requests
options '*' do
  response.headers['Allow'] = 'GET,HEAD,POST,OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
  200
end

# Health check endpoint
get '/api/health' do
  content_type :json
  {
    status: 'ok',
    message: 'Token Top-Up API is running',
    version: '1.0.0'
  }.to_json
end

# Process endpoint - Main API
post '/api/process' do
  content_type :json
  
  begin
    puts "\n=== Received POST request to /api/process ==="
    
    # Parse request body
    request.body.rewind
    body_content = request.body.read
    puts "Request body size: #{body_content.length} bytes"
    
    payload = JSON.parse(body_content)
    
    users = payload['users']
    companies = payload['companies']
    
    puts "Users count: #{users&.length || 0}"
    puts "Companies count: #{companies&.length || 0}"
    
    # Validate input
    unless users && companies
      status 400
      return {
        success: false,
        error: 'Missing required fields: users and companies'
      }.to_json
    end
    
    unless users.is_a?(Array) && companies.is_a?(Array)
      status 400
      return {
        success: false,
        error: 'Users and companies must be arrays'
      }.to_json
    end
    
    # Create temp directory if it doesn't exist
    Dir.mkdir('tmp') unless File.exist?('tmp')
    
    # Generate unique filenames
    timestamp = Time.now.to_i
    users_file = "tmp/users_#{timestamp}.json"
    companies_file = "tmp/companies_#{timestamp}.json"
    output_file = "tmp/output_#{timestamp}.txt"
    
    # Write JSON data to temp files
    File.write(users_file, JSON.pretty_generate(users))
    File.write(companies_file, JSON.pretty_generate(companies))
    
    # Let challenge.rb do ALL the processing
    processor = TokenTopUpProcessor.new(
      users_file: users_file,
      companies_file: companies_file,
      output_file: output_file
    )
    
    # Capture STDERR to catch any errors
    original_stderr = $stderr
    $stderr = StringIO.new
    
    success = processor.process
    
    error_output = $stderr.string
    $stderr = original_stderr
    
    if success && File.exist?(output_file)
      puts "✓ Processing successful!"
      
      # Read the output that challenge.rb generated
      output_content = File.read(output_file)
      
      # Parse the output text to create JSON for the frontend
      result_data = parse_output_to_json(output_content, users, companies)
      
      response = {
        success: true,
        output: output_content,
        result: result_data
      }
      
      # Cleanup temp files
      cleanup_files(users_file, companies_file, output_file)
      
      status 200
      response.to_json
    else
      # Processing failed
      puts "✗ Processing failed!"
      puts "Error output: #{error_output}" unless error_output.empty?
      
      cleanup_files(users_file, companies_file, output_file)
      
      status 500
      {
        success: false,
        error: 'Processing failed',
        details: error_output.empty? ? 'Unknown error' : error_output
      }.to_json
    end
    
  rescue JSON::ParserError => e
    puts "✗ JSON Parse Error: #{e.message}"
    status 400
    {
      success: false,
      error: 'Invalid JSON format',
      details: e.message
    }.to_json
  rescue StandardError => e
    puts "✗ Server Error: #{e.message}"
    puts e.backtrace.first(3)
    status 500
    {
      success: false,
      error: 'Internal server error',
      details: e.message,
      backtrace: e.backtrace.first(5)
    }.to_json
  end
end

# Parse the text output from challenge.rb into JSON structure for frontend
# This just transforms the already-processed output, doesn't re-process
def parse_output_to_json(output_text, users_data, companies_data)
  result = []
  current_company = nil
  current_users = []
  
  # Build lookup maps
  company_map = companies_data.each_with_object({}) { |c, h| h[c['id']] = c }
  user_map = users_data.each_with_object({}) { |u, h| h[u['email']] = u }
  
  output_text.split("\n").each do |line|
    if line =~ /\tCompany Id: (\d+)/
      # Save previous company if exists
      if current_company
        result << {
          company: current_company,
          users: current_users,
          total_top_up: current_users.sum { |u| u['top_up_amount'] }
        }
      end
      
      company_id = $1.to_i
      current_company = company_map[company_id]
      current_users = []
      
    elsif line =~ /\t\t([^,]+), ([^,]+), (.+@.+)/
      # User line
      last_name = $1.strip
      first_name = $2.strip
      email = $3.strip
      
      original_user = user_map[email]
      if original_user
        current_users << {
          **original_user,
          'company_name' => current_company['name'],
          'top_up_amount' => current_company['top_up'],
          'new_balance' => original_user['tokens'] + current_company['top_up'],
          'email_sent' => line.include?('Email sent') # Check next few lines or parse more
        }
      end
    elsif line =~ /\t\t  Email (sent|not sent)/
      # Update last user's email status
      current_users.last['email_sent'] = $1 == 'sent' unless current_users.empty?
    end
  end
  
  # Save last company
  if current_company
    result << {
      company: current_company,
      users: current_users,
      total_top_up: current_users.sum { |u| u['top_up_amount'] }
    }
  end
  
  result
end

# Cleanup temporary files
def cleanup_files(*files)
  files.each do |file|
    File.delete(file) if File.exist?(file)
  rescue StandardError => e
    warn "Failed to delete #{file}: #{e.message}"
  end
end

# Error handlers
error 404 do
  content_type :json
  { success: false, error: 'Endpoint not found' }.to_json
end

error 500 do
  content_type :json
  { success: false, error: 'Internal server error' }.to_json
end

# Startup message
if __FILE__ == $PROGRAM_NAME
  puts "\n" + "="*60
  puts "🚀 Token Top-Up API Server"
  puts "="*60
  puts "Server running at: http://localhost:4567"
  puts "Health check: http://localhost:4567/api/health"
  puts "API endpoint: http://localhost:4567/api/process"
  puts "\nReact frontend should run on: http://localhost:5173 (Vite default)"
  puts "                        or: http://localhost:3000 (Create React App)"
  puts "Press Ctrl+C to stop the server"
  puts "="*60 + "\n\n"
end