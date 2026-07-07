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

# 変数定義
variable "rg_name" {
  type    = string
  default = "リソースグループ名"
}

variable "app_name" {
  type    = string
  default = "your-unique-app-name"
}

variable "log_analytics_workspace_id" {
  type    = string
  default = "LogAnalyticsワークスペースのResourceID"
}

# 共通タグの変数定義（呼び出し元やtfvarsから動的に指定可能）
variable "tags" {
  type = map(string)
  default = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# 1. App Service Plan (B1)
resource "azurerm_service_plan" "plan" {
  name                = "${var.app_name}-asp"
  resource_group_name = var.rg_name
  location            = "japaneast"
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = var.tags
}

# 2. App Service (Linux / Node.js 20-lts / スタートアップコマンド設定)
resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  resource_group_name = var.rg_name
  location            = "japaneast"
  service_plan_id     = azurerm_service_plan.plan.id
  tags                = var.tags

  site_config {
    application_stack {
      node_version = "20-lts"
    }
    app_command_line = "npx next start"
  }
}

# 3. Application Insights (既存のワークスペースに紐づけ)
resource "azurerm_application_insights" "app_ins" {
  name                = "${var.app_name}-ai"
  location            = "japaneast"
  resource_group_name = var.rg_name
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id
  tags                = var.tags
}

# 4. App Service の診断設定 (Log Analytics ワークスペースへのログ送信)
resource "azurerm_monitor_diagnostic_setting" "app_diag" {
  name                       = "${var.app_name}-diag"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }
  enabled_log {
    category = "AppServiceConsoleLogs"
  }
  enabled_log {
    category = "AppServiceApplicationLogs"
  }
  enabled_log {
    category = "AppServiceAccessAuditLogs"
  }
  enabled_log {
    category = "AppServiceIPSecAuditLogs"
  }
  enabled_log {
    category = "AppServicePlatformLogs"
  }
}
