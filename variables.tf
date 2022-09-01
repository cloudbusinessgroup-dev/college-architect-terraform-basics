variable "tenant_id" {
  type        = string
  description = "ID of the azure tenant"
  default = "28966094-c809-495e-9ae5-2019d0372648"
}

variable "subscription_id" {
  type        = string
  description = "ID of the azure subscription"
  default = "f0468dde-8080-46e2-b47b-6a1cb0abe566"
}

variable "location" {
  type        = string
  description = "Azure location"
  default = "West Europe"
}

variable "client_id" {
  type        = string
  description = "The College App Registration ID we have created before"
  default = "e7e20ab3-47ba-4cb2-94fa-f9143304627a"
}

variable "object_id" {
  type        = string
  description = "The College App Registration object id"
  default     = "18ecd97e-0499-477f-8129-85030620b747" 
}


variable "client_secret" {
  type        = string
  description = "The College App Registration client secret we have created before"
  default = ".Ji8Q~_rm9aj8-CeXBJkEvkRqlVxsKmBKCzpBaoB"
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

variable "backend_private_dns" {
  type        = string
  description = "Private DNS"
  default     = "cloudbusinessgroup.azure"
}

variable "backend_dns_privatelink" {
  type        = string
  description = "SQL DNS Private Link"
  default     = "cloudbusinessgroup"
}

variable "initial_deployment_keyvault" {
  type        = bool
  description = "Define if new initial passwords for servers should be created"
  default     = false
}