# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'sequent/support'
require_relative '../../migration_class'

class ActiveRecordPersistorTest < Sequent::ApplicationRecord; end

describe Sequent::Core::Persistors::ActiveRecordPersistor do
  let(:migrations_path) { File.expand_path(database_name, Dir.tmpdir).tap { |dir| Dir.mkdir(dir) } }
  let(:database_name) { Sequent.new_uuid }
  let(:db_config) do
    Database.test_config.merge(
      'database' => database_name,
    )
  end
  before do
    Sequent::Support::Database.create!(db_config)
    ActiveRecord::Base.establish_connection(db_config)
  end
  after do
    Sequent::Support::Database.drop!(db_config)
    Sequent::Support::Database.disconnect!
  end

  let(:database) { Sequent::Support::Database.new }

  after { FileUtils.rm_rf(migrations_path) }

  before :each do
    File.open(File.expand_path('1_test_migration.rb', migrations_path), 'w') do |f|
      f.write <<~EOF
        class TestMigration < MigrationClass
          def change
            create_table "active_record_persistor_tests", id: false do |t|
              t.string "name", null: false
              t.string "initials", default: [], array:true
              t.timestamp "created_at", null: false
              t.timestamp "updated_at", null: false
            end
          end
        end
      EOF
      f.flush
      database.migrate(migrations_path, verbose: false)
    end
  end

  let(:persistor) { Sequent::Core::Persistors::ActiveRecordPersistor.new }

  context 'create_records' do
    it 'inserts records by batch' do
      expect do
        persistor.create_records(
          ActiveRecordPersistorTest,
          [
            {name: 'kim', created_at: DateTime.now, updated_at: DateTime.now},
            {name: 'ben', created_at: DateTime.now, updated_at: DateTime.now},
          ],
        )
      end.to change { ActiveRecordPersistorTest.count }.by(2)
    end

    it 'can insert array values' do
      expect do
        persistor.create_records(
          ActiveRecordPersistorTest,
          [
            {name: 'john', initials: %w[j f], created_at: DateTime.now, updated_at: DateTime.now},
          ],
        )
      end.to change { ActiveRecordPersistorTest.count }.by(1)
    end
  end

  context 'update_all_records' do
    it 'can updates records by batch' do
      persistor.create_record(ActiveRecordPersistorTest, {name: 'kim', initials: %w[j j]})

      persistor.update_all_records(ActiveRecordPersistorTest, {name: 'kim'}, {initials: %w[k k]})

      expect(persistor.get_record(ActiveRecordPersistorTest, {name: 'kim'}).initials).to eq %w[k k]
    end
  end
end
