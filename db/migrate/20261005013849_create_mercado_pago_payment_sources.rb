class CreateMercadoPagoPaymentSources < ActiveRecord::Migration[8.1]
  def change
    create_table :mercado_pago_payment_sources do |t|
      t.references :payment_method, foreign_key: { to_table: :spree_payment_methods }
      t.string :payer_document

      t.string :mp_order_id, index: { unique: true }
      t.string :mp_payment_id
      t.datetime :expires_at

      t.text :qr_code
      t.text :qr_code_base64
      t.string :ticket_url, limit: 1024
      t.string :digitable_line
      t.string :barcode_content

      t.timestamps
    end
  end
end
