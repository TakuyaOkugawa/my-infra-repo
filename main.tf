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

# ==========================================
# 固定値（既存のリソースグループとLog Analytics）
# ==========================================
locals {
  # 既存のリソースグループ名を固定
  rg_name                    = "sandbox" 
  
  # 既存のLog Analytics Workspace IDを固定
  log_analytics_workspace_id = "/subscriptions/a5d00c95-1d29-40d3-8130-5fd396638e91/resourceGroups/sandbox/providers/Microsoft.OperationalInsights/workspaces/sandbox-log-analytics"
}

# ==========================================
# アプリ側から受け取る変数
# ==========================================
variable "app_name" {
  type = string
}

# ランタイム（Node.js, Python など）を指定する変数
variable "runtime_stack" {
  type    = string
  default = "node" # "node" または "python"
}

# ランタイムのバージョンを指定する変数
variable "runtime_version" {
  type    = string
  default = "20-lts" # Pythonの場合は "3.11" など
}

# アプリケーションの起動コマンドを指定する変数
variable "app_command_line" {
  type    = string
  default = "npx next start" # Pythonの場合は "gunicorn --bind=0.0.0.0 --timeout 600 app:app" など
}

# タグをセット
variable "tags" {
  type = map(string)
  default = {}
}

locals {
  common_tags = {
    App = var.app_name
  }
}

# ==========================================
# リソース定義
# ==========================================

resource "azurerm_service_plan" "plan" {
  name                = "$asp-{var.app_name}"
  resource_group_name = local.rg_name
  location            = "japaneast"
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "app" {
  name                = app-var.app_name
  resource_group_name = local.rg_name
  location            = "japaneast"
  service_plan_id     = azurerm_service_plan.plan.id
  tags                = local.common_tags

site_config {
    application_stack {
      node_version   = var.runtime_stack == "node" ? var.runtime_version : null
      python_version = var.runtime_stack == "python" ? var.runtime_version : null
      java_version   = var.runtime_stack == "java" ? var.runtime_version : null
      dotnet_version = var.runtime_stack == "dotnet" ? var.runtime_version : null
      php_version    = var.runtime_stack == "php" ? var.runtime_version : null
      ruby_version   = var.runtime_stack == "ruby" ? var.runtime_version : null
    }
    app_command_line = var.app_command_line
  }

resource "azurerm_application_insights" "app_ins" {
  name                = "${var.app_name}-insights"
  location            = "japaneast"
  resource_group_name = local.rg_name
  application_type    = "web"
  workspace_id        = local.log_analytics_workspace_id
  tags                = local.common_tags
}

resource "azurerm_monitor_diagnostic_setting" "app_diag" {
  name                       = "${var.app_name}-diagnostic"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = local.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
  enabled_log {
    category = "AppServiceConsoleLogs"
  }
  enabled_log {
    category = "AppServiceAppLogs"
  }
  enabled_log {
    category = "AppServiceAuditLogs"
  }
  enabled_log {
    category = "AppServiceIPSecAuditLogs"
  }
  enabled_log {
    category = "AppServicePlatformLogs"
  }
}
