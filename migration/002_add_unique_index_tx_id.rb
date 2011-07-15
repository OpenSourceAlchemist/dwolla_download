require 'sequel_postgresql_triggers'
Class.new(Sequel::Migration) do
  def up
    #Type,Date,Gross,Fee,Fee ID,Amount,ID,Source,Source ID,Destination,Destination ID,Comments
    alter_table(:dwolla_transactions) do
      add_index(:txid, :unique => true)
    end
  end

  def down
    alter_table(:dwolla_transactions) do
      drop_index(:txid)
    end
  end
end
