output "sql_private_link_endpoint_ip" {
  description = "SQL Private Link Endpoint IP"
  value = data.azurerm_private_endpoint_connection.endpoint-connection.private_service_connection.0.private_ip_address
}

output "sql_db" {
  description = "SQL Server DB and Database"
  value = "${azurerm_sql_database.sql-db.server_name}/${azurerm_sql_database.sql-db.name}"
}