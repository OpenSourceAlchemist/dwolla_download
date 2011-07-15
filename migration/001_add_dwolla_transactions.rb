require 'sequel_postgresql_triggers'
Class.new(Sequel::Migration) do
  def up
    #Type,Date,Gross,Fee,Fee ID,Amount,ID,Source,Source ID,Destination,Destination ID,Comments
    create_table(:dwolla_transactions) do
      primary_key :id
      String   :type, null: false
      DateTime :date, null: false
      BigDecimal :gross, null: false
      BigDecimal :fee, null: false
      String :fee_id, null: false
      BigDecimal   :amount, null: false
      String   :txid, null: false
      String   :source_account
      String   :source_id
      String   :destination_account
      String   :destination_id
      String   :comment, null: false
      DateTime :created_at, default: :now.sql_function()
    end
    pgt_created_at :dwolla_transactions, :created_at
  end

  def down
    drop_table(:dwolla_transactions)
  end
end
