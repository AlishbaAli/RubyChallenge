# frozen_string_literal: true

require 'rspec'
require 'json'
require 'fileutils'
require_relative '../challenge'

RSpec.describe TokenTopUpProcessor do
  let(:temp_dir) { 'spec/tmp' }
  let(:users_file) { "#{temp_dir}/users.json" }
  let(:companies_file) { "#{temp_dir}/companies.json" }
  let(:output_file) { "#{temp_dir}/output.txt" }
  
  let(:valid_companies) do
    [
      { 'id' => 1, 'name' => 'Blue Cat Inc.', 'top_up' => 71, 'email_status' => false },
      { 'id' => 2, 'name' => 'Yellow Mouse Inc.', 'top_up' => 37, 'email_status' => true },
      { 'id' => 3, 'name' => 'Red Horse Inc.', 'top_up' => 55, 'email_status' => true }
    ]
  end
  
  let(:valid_users) do
    [
      {
        'id' => 1,
        'first_name' => 'John',
        'last_name' => 'Doe',
        'email' => 'john.doe@test.com',
        'company_id' => 1,
        'email_status' => true,
        'active_status' => true,
        'tokens' => 50
      },
      {
        'id' => 2,
        'first_name' => 'Jane',
        'last_name' => 'Smith',
        'email' => 'jane.smith@test.com',
        'company_id' => 2,
        'email_status' => true,
        'active_status' => true,
        'tokens' => 75
      }
    ]
  end
  
  let(:processor) do
    described_class.new(
      users_file: users_file,
      companies_file: companies_file,
      output_file: output_file
    )
  end

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  def write_json(file, data)
    File.write(file, JSON.pretty_generate(data))
  end

  def read_output
    File.read(output_file)
  end

  describe '#initialize' do
    it 'sets default file paths' do
      processor = described_class.new
      expect(processor.users_file).to eq('users.json')
      expect(processor.companies_file).to eq('companies.json')
      expect(processor.output_file).to eq('output.txt')
    end

    it 'accepts custom file paths' do
      expect(processor.users_file).to eq(users_file)
      expect(processor.companies_file).to eq(companies_file)
      expect(processor.output_file).to eq(output_file)
    end
  end

  describe '#process' do
    context 'with valid data' do
      before do
        write_json(users_file, valid_users)
        write_json(companies_file, valid_companies)
      end

      it 'returns true on success' do
        expect(processor.process).to be true
      end

      it 'creates an output file' do
        processor.process
        expect(File.exist?(output_file)).to be true
      end

      it 'includes company information in output' do
        processor.process
        output = read_output
        expect(output).to include('Company Id: 1')
        expect(output).to include('Company Name: Blue Cat Inc.')
      end

      it 'includes user information in output' do
        processor.process
        output = read_output
        expect(output).to include('Doe, John')
        expect(output).to include('john.doe@test.com')
      end

      it 'calculates new token balance correctly' do
        processor.process
        output = read_output
        expect(output).to include('Previous Token Balance, 50')
        expect(output).to include('New Token Balance 121') # 50 + 71
      end

      it 'respects email status logic' do
        processor.process
        output = read_output
        # John: user true, company false = no email
        expect(output).to include('Doe, John')
        expect(output).to match(/Doe, John.*Email not sent/m)
        # Jane: user true, company true = email sent
        expect(output).to include('Smith, Jane')
        expect(output).to match(/Smith, Jane.*Email sent/m)
      end

      it 'calculates total top-ups correctly' do
        processor.process
        output = read_output
        expect(output).to include('Total amount of top ups for Blue Cat Inc.: 71')
        expect(output).to include('Total amount of top ups for Yellow Mouse Inc.: 37')
      end
    end

    context 'with missing files' do
      it 'returns false when users file is missing' do
        write_json(companies_file, valid_companies)
        expect(processor.process).to be false
      end

      it 'returns false when companies file is missing' do
        write_json(users_file, valid_users)
        expect(processor.process).to be false
      end

      it 'logs error for missing users file' do
        write_json(companies_file, valid_companies)
        expect { processor.process }.to output(/Users file not found/).to_stderr
      end

      it 'logs error for missing companies file' do
        write_json(users_file, valid_users)
        expect { processor.process }.to output(/Companies file not found/).to_stderr
      end
    end

    context 'with invalid JSON' do
      it 'returns false for malformed users JSON' do
        File.write(users_file, '[{"id": 1 "name": "test"}]')
        write_json(companies_file, valid_companies)
        expect(processor.process).to be false
      end

      it 'returns false for malformed companies JSON' do
        write_json(users_file, valid_users)
        File.write(companies_file, '[{"id": 1 "name": "test"}]')
        expect(processor.process).to be false
      end

      it 'logs error for invalid JSON' do
        File.write(users_file, 'not json')
        write_json(companies_file, valid_companies)
        expect { processor.process }.to output(/Invalid JSON/).to_stderr
      end
    end

    context 'with empty data' do
      it 'handles empty users array' do
        write_json(users_file, [])
        write_json(companies_file, valid_companies)
        expect(processor.process).to be true
      end

      it 'handles empty companies array' do
        write_json(users_file, valid_users)
        write_json(companies_file, [])
        expect(processor.process).to be true
      end

      it 'creates empty output for empty users' do
        write_json(users_file, [])
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output.strip).to be_empty
      end
    end

    context 'with inactive users' do
      let(:inactive_users) do
        valid_users.map { |u| u.merge('active_status' => false) }
      end

      it 'excludes inactive users from output' do
        write_json(users_file, inactive_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).not_to include('Doe, John')
        expect(output).not_to include('Smith, Jane')
      end

      it 'processes successfully with all inactive users' do
        write_json(users_file, inactive_users)
        write_json(companies_file, valid_companies)
        expect(processor.process).to be true
      end
    end

    context 'with orphaned users' do
      let(:orphaned_users) do
        [
          valid_users[0],
          valid_users[1].merge('company_id' => 999)
        ]
      end

      it 'excludes users with non-existent company_id' do
        write_json(users_file, orphaned_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include('Doe, John')
        expect(output).not_to include('Smith, Jane')
      end
    end

    context 'with bad data types' do
      let(:bad_type_users) do
        [
          valid_users[0],
          {
            'id' => 'string_id',
            'first_name' => 'Bad',
            'last_name' => 'User',
            'email' => 'bad@test.com',
            'company_id' => '1',
            'email_status' => 'yes',
            'active_status' => true,
            'tokens' => '50'
          }
        ]
      end

      it 'skips users with invalid data types' do
        write_json(users_file, bad_type_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include('Doe, John')
        expect(output).not_to include('Bad, User')
      end
    end

    context 'with missing required fields' do
      let(:incomplete_users) do
        [
          valid_users[0],
          {
            'id' => 2,
            'first_name' => 'Incomplete'
            # Missing other required fields
          }
        ]
      end

      it 'skips users with missing required fields' do
        write_json(users_file, incomplete_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include('Doe, John')
        expect(output).not_to include('Incomplete')
      end
    end

    context 'with null values' do
      let(:null_users) do
        [
          valid_users[0],
          valid_users[1].merge('first_name' => nil)
        ]
      end

      it 'skips users with null values in required fields' do
        write_json(users_file, null_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include('Doe, John')
        expect(output).not_to include('Smith, Jane')
      end
    end

    context 'with email status combinations' do
      let(:email_test_users) do
        [
          # User true, Company false (company 1)
          valid_users[0].merge('email_status' => true, 'company_id' => 1),
          # User false, Company true (company 2)
          valid_users[1].merge('email_status' => false, 'company_id' => 2, 'last_name' => 'Alpha'),
          # User true, Company true (company 2)
          valid_users[0].merge('id' => 3, 'email_status' => true, 'company_id' => 2, 'last_name' => 'Zebra'),
          # User false, Company false (company 1)
          valid_users[1].merge('id' => 4, 'email_status' => false, 'company_id' => 1, 'last_name' => 'Beta')
        ]
      end

      it 'sends email only when both user and company email_status are true' do
        write_json(users_file, email_test_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        
        # User true + Company false = no email
        expect(output).to match(/Doe, John.*Email not sent/m)
        # User false + Company true = no email
        expect(output).to match(/Alpha, Jane.*Email not sent/m)
        # User true + Company true = email sent
        expect(output).to match(/Zebra, John.*Email sent/m)
        # User false + Company false = no email
        expect(output).to match(/Beta, Jane.*Email not sent/m)
      end
    end

    context 'with sorting requirements' do
      let(:unsorted_users) do
        [
          valid_users[0].merge('last_name' => 'Zimmerman', 'company_id' => 2),
          valid_users[1].merge('last_name' => 'Anderson', 'company_id' => 2),
          valid_users[0].merge('id' => 3, 'last_name' => 'Miller', 'company_id' => 1)
        ]
      end

      it 'sorts companies by id' do
        write_json(users_file, unsorted_users)
        write_json(companies_file, valid_companies.reverse)
        processor.process
        output = read_output
        
        # Company 1 should appear before Company 2
        company1_pos = output.index('Company Id: 1')
        company2_pos = output.index('Company Id: 2')
        expect(company1_pos).to be < company2_pos
      end

      it 'sorts users alphabetically by last name within company' do
        write_json(users_file, unsorted_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        
        # Within Company 2, Anderson should come before Zimmerman
        anderson_pos = output.index('Anderson')
        zimmerman_pos = output.index('Zimmerman')
        expect(anderson_pos).to be < zimmerman_pos
      end

      it 'sorts case-insensitively' do
        case_users = [
          valid_users[0].merge('last_name' => 'smith', 'company_id' => 1),
          valid_users[1].merge('last_name' => 'Anderson', 'company_id' => 1)
        ]
        write_json(users_file, case_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        
        anderson_pos = output.index('Anderson')
        smith_pos = output.index('smith')
        expect(anderson_pos).to be < smith_pos
      end
    end

    context 'with special characters' do
      let(:special_char_users) do
        [
          valid_users[0].merge(
            'first_name' => "José",
            'last_name' => "O'Brien-Smith"
          )
        ]
      end

      it 'handles special characters in names' do
        write_json(users_file, special_char_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include("O'Brien-Smith, José")
      end
    end

    context 'with duplicate user IDs' do
      let(:duplicate_users) do
        [
          valid_users[0],
          valid_users[0].merge('first_name' => 'Different')
        ]
      end

      it 'processes both users with duplicate IDs' do
        write_json(users_file, duplicate_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include('Doe, John')
        expect(output).to include('Doe, Different')
      end
    end

    context 'with negative values' do
      let(:negative_users) do
        [
          valid_users[0].merge('tokens' => -10)
        ]
      end

      it 'processes users with negative token values' do
        write_json(users_file, negative_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include('Previous Token Balance, -10')
        expect(output).to include('New Token Balance 61') # -10 + 71
      end
    end

    context 'with large numbers' do
      let(:large_number_users) do
        [
          valid_users[0].merge('tokens' => 999999)
        ]
      end

      it 'handles large token values' do
        write_json(users_file, large_number_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        expect(output).to include('Previous Token Balance, 999999')
        expect(output).to include('New Token Balance 1000070')
      end
    end

    context 'with multiple users per company' do
      let(:multiple_users) do
        [
          valid_users[0].merge('company_id' => 1),
          valid_users[1].merge('company_id' => 1, 'last_name' => 'Alpha'),
          valid_users[0].merge('id' => 3, 'company_id' => 1, 'last_name' => 'Zebra')
        ]
      end

      it 'calculates correct total for company' do
        write_json(users_file, multiple_users)
        write_json(companies_file, valid_companies)
        processor.process
        output = read_output
        # 3 users * 71 top_up = 213
        expect(output).to include('Total amount of top ups for Blue Cat Inc.: 213')
      end
    end
  end

  describe 'edge cases' do
    it 'handles zero token balances' do
      users = [valid_users[0].merge('tokens' => 0)]
      write_json(users_file, users)
      write_json(companies_file, valid_companies)
      processor.process
      output = read_output
      expect(output).to include('Previous Token Balance, 0')
      expect(output).to include('New Token Balance 71')
    end

    it 'handles zero top-up amounts' do
      companies = [valid_companies[0].merge('top_up' => 0)]
      users = [valid_users[0].merge('company_id' => 1)]
      write_json(users_file, users)
      write_json(companies_file, companies)
      processor.process
      output = read_output
      expect(output).to include('New Token Balance 50') # 50 + 0
    end

    it 'handles empty string names gracefully' do
      users = [valid_users[0].merge('first_name' => '', 'last_name' => '')]
      write_json(users_file, users)
      write_json(companies_file, valid_companies)
      processor.process
      output = read_output
      expect(output).to include(', ')
    end
  end

  describe 'output format' do
    before do
      write_json(users_file, valid_users)
      write_json(companies_file, valid_companies)
      processor.process
    end

    it 'uses correct indentation for company info' do
      output = read_output
      expect(output).to match(/^\tCompany Id: \d+$/)
      expect(output).to match(/^\tCompany Name: .+$/)
      expect(output).to match(/^\tUsers Emailed:$/)
    end

    it 'uses correct indentation for user info' do
      output = read_output
      expect(output).to match(/^\t\t[^,]+, [^,]+, .+@.+$/)
      expect(output).to match(/^\t\t  Previous Token Balance, \d+$/)
      expect(output).to match(/^\t\t  New Token Balance \d+$/)
    end

    it 'separates companies with blank lines' do
      output = read_output
      expect(output).to match(/Total amount of top ups.*\n\n\tCompany/m)
    end
  end
end