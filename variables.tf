variable "tenant_id" {
  type        = string
  description = "ID of the azure tenant"
  default = ""
}

variable "subscription_id" {
  type        = string
  description = "ID of the azure subscription"
  default = ""
}

variable "location" {
  type        = string
  description = "Azure location"
  default = "West Europe"
}

variable "client_id" {
  type        = string
  description = "The College App Registration ID we have created before"
  default = ""
}

variable "client_secret" {
  type        = string
  description = "The College App Registration client secret we have created before"
  default = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags for the environment"
  default     = {
    env             = "COLLEGEDEV"
    product_id      = "COLL_0000"
    application     = "APP-COLL-00000"
    app_name        = "COLL-INFRA"
    costcenter      = "0000"
    Participants    = "<<Your Name>>"
  }
}

variable "location_short" {
  type        = string
  description = "Azure location - short code"
  default = "WEU"
}

variable "env_name" {
  type        = string
  description = "Name of the environment" 
  default     = "DEV"
}

variable "coll_prefix" {
  type        = string
  description = "Name of the environment" 
  default     = "COLLEGE-INFRA"
}