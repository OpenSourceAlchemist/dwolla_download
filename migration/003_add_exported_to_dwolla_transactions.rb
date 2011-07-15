Class.new(Sequel::Migration) do
  def up
    #Type,Date,Gross,Fee,Fee ID,Amount,ID,Source,Source ID,Destination,Destination ID,Comments
    alter_table(:dwolla_transactions) do
      add_column(:exported, :boolean, :default => false)
    end
  end

  def down
    alter_table(:dwolla_transactions) do
      drop_column(:exported)
    end
  end
end
