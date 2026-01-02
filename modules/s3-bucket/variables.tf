# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the S3 bucket"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - General
# ---------------------------------------------------------------------------------------------------------------------

variable "block_public_access" {
  description = "If set to true, block all public access on this bucket. Set to false for CDN buckets."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "If set to true, delete all the contents of the bucket when running 'destroy' on this resource. Should typically only be enabled for automated testing."
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "If set to true, enable versioning on the bucket to protect against accidental or malicious deletion/modification of objects."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to apply to the bucket"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Static Website Hosting (CDN)
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_website_hosting" {
  description = "Enable static website hosting. Required for CDN buckets served via Cloudflare."
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "The index document for the website"
  type        = string
  default     = "index.html"
}

variable "website_error_document" {
  description = "The error document for the website"
  type        = string
  default     = "error.html"
}

variable "enable_public_read" {
  description = "Allow public read access to objects. Required for CDN buckets. Must set block_public_access = false."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - CORS Configuration (CDN)
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_cors" {
  description = "Enable CORS configuration for cross-domain asset requests"
  type        = bool
  default     = false
}

variable "cors_allowed_headers" {
  description = "Allowed headers for CORS requests"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "Allowed HTTP methods for CORS requests"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "cors_allowed_origins" {
  description = "Allowed origins for CORS requests. Use ['*'] for public CDN."
  type        = list(string)
  default     = ["*"]

  validation {
    condition = alltrue([
      for origin in var.cors_allowed_origins :
      origin == "*" || can(regex("^https?://", origin))
    ])
    error_message = "CORS origins must be '*' or valid URLs starting with 'http://' or 'https://'"
  }
}

variable "cors_expose_headers" {
  description = "Headers to expose in CORS responses"
  type        = list(string)
  default     = ["ETag"]
}

variable "cors_max_age_seconds" {
  description = "Max age in seconds for CORS preflight cache"
  type        = number
  default     = 3600
}
