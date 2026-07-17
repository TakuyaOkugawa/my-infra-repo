terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "rg_name" {
  type = string
}

variable "app_name" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

# ランタイム（Node.js, Python など）を指定する変数
variable "runtime_stack" {
  type = string
  default = "node" # "node" または "python"
}

# ランタイムのバージョンを指定する変数
variable "runtime_version" {
  type = string
  default = "20-lts" # Pythonの場合は "3.11" など
}

# アプリケーションの起動コマンドを指定する変数
variable "app_command_line" {
  type = string
  default = "npx next start" # Pythonの場合は "gunicorn --bind=0.0.0.0 --timeout 600 app:app" など
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_service_plan" "plan" {
  name                = "${var.app_name}-asp"
  resource_group_name = var.rg_name
  location            = "japaneast"
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = merge(var.tags, { Environment = var.app_name })
}

resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  resource_group_name = var.rg_name
  location            = "japaneast"
  service_plan_id     = azurerm_service_plan.plan.id
  tags                = merge(var.tags, { Environment = var.app_name })

  site_config {
    application_stack {
      node_version   = var.runtime_stack == "node" ? var.runtime_version : null
      python_version = var.runtime_stack == "python" ? var.runtime_version : null
    }
    app_command_line = var.app_command_line
  }
}

resource "azurerm_application_insights" "app_ins" {
  name                = "${var.app_name}-ai"
  location            = "japaneast"
  resource_group_name = var.rg_name
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id
  tags                = merge(var.tags, { Environment = var.app_name })
}

resource "azurerm_monitor_diagnostic_setting" "app_diag" {
  name                       = "${var.app_name}-diag"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceApplicationLogs" }
  enabled_log { category = "AppServiceAccessAuditLogs" }
  enabled_log { category = "AppServiceIPSecAuditLogs" }
  enabled_log { category = "AppServicePlatformLogs" }
}
