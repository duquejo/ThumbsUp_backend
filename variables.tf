variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-2"
}

locals {
  dot_env_file_path = ".env"
  dot_env_regex     = "(?m:^\\s*([^#\\s]\\S*)\\s*=\\s*[\"']?(.*[^\"'\\s])[\"']?\\s*$)"
  dot_env           = { for tuple in regexall(local.dot_env_regex, file(local.dot_env_file_path)) : tuple[0] => sensitive(tuple[1]) }
  envs              = local.dot_env
}